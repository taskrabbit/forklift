require 'mysql2'

module Forklift
  class Connection

    def connection
      @connection
    end

    def logger
      @logger
    end

    def args
      @args
    end

    def threads
      @threads
    end

    def name
      @name
    end

    def initialize(name, args, logger, threads=1)
      @name = name
      @args = args
      @logger = logger
      @threads = threads
      @connection = Mysql2::Client.new(@args);
      connection_test
    end

    def q(query)
      logger.debug "[ #{@name} ] #{query}"
      begin
        response = connection.query(query);
        if hash_count(response) == 0
          return nil
        elsif hash_count(response) == 1
          response.first.each do |k,v|
            return v
          end 
        else
          response
        end
      rescue Exception => e
        logger.fatal "mySQL error: #{e}"
      end
    end

    def parallel_query(queries)
      parallel_runner ||= Forklift::ParallelQuery.new(args, threads, logger)
      parallel_runner.run(queries)
    end

    def connection_test
      begin
        connection.query("select NOW()")
      rescue Error => e
        logger.fatal "Connection Error: #{e}"
      end
    end

    def local_copy_tables(from, to, skipped_tables=[], to_prefix=false, frequency=nil, forklift_data_table)
      logger.log "Cloning local database `#{from}` to `#{to}`"
      get_tables(from).each do |table|
        destination_table_name = generate_name(from, table, to_prefix)
        if skipped_tables.include?(table)
          logger.log " > Explicitly Skipping table `#{destination_table_name}`"
        elsif frequency_check(to, destination_table_name, forklift_data_table, frequency)
          logger.log " > cloning `#{table}` to `#{destination_table_name}`"
          q("drop table if exists `#{to}`.`#{destination_table_name}`")
          q("create table `#{to}`.`#{destination_table_name}` like `#{from}`.`#{table}`")
          q("insert into `#{to}`.`#{destination_table_name}` select * from `#{from}`.`#{table}`")
          q("delete from `#{to}`.`#{forklift_data_table}` where name='#{destination_table_name}' and type='extraction'")
          q("insert into `#{to}`.`#{forklift_data_table}` (created_at, name, type) values (NOW(), '#{destination_table_name}', 'extraction') ")
        else
          logger.log " > Skipping table `#{destination_table_name}` because last import was too recently"
        end
      end
    end

    def remote_copy_tables(local_connection, from, to, skipped_tables=[], to_prefix=false, frequency=nil, forklift_data_table)
      #TODO Each table imported can be a thread
      #TODO Selects from remote tables should be done in batches

      logger.log "Cloning remote database `#{from}` to `#{to}`"
      get_tables(from).each do |table|
        destination_table_name = generate_name(from, table, to_prefix)
        if skipped_tables.include?(table)
          logger.log " > Explicitly Skipping table `#{destination_table_name}`"
        elsif local_connection.frequency_check(to, destination_table_name, forklift_data_table, frequency)
          logger.log " > importing remote table `#{table}` to local `#{destination_table_name}`"
          local_connection.q("drop table if exists `#{to}`.`#{destination_table_name}`")
          create_table_command = connection.query("show create table #{table}").first["Create Table"]
          create_table_command.gsub!("CREATE TABLE `#{table}`", "CREATE TABLE `#{destination_table_name}`")
          local_connection.q("use #{to}")
          local_connection.q(create_table_command)
          connection.query("select * from #{table}", :cast => false).each do |row|
            sql = build_remote_insert_row(row, to, destination_table_name)
            local_connection.q(sql)
          end
          local_connection.q("delete from `#{to}`.`#{forklift_data_table}` where name='#{destination_table_name}' and type='extraction'")
          local_connection.q("insert into `#{to}`.`#{forklift_data_table}` (created_at, name, type) values (NOW(), '#{destination_table_name}', 'extraction') ")
        else
          logger.log " > Skipping table `#{destination_table_name}` because last import was too recently"
        end
      end
    end

    def direct_local_copy(from, to)
      logger.log "Copping database `#{from}` to `#{to}`"
      get_tables(from).each do |table|
        q("drop table if exists `#{to}`.`#{table}`")
        q("create table `#{to}`.`#{table}` like `#{from}`.`#{table}`")
        q("insert into `#{to}`.`#{table}` select * from `#{from}`.`#{table}`")
      end
    end

    def delete_and_recreate_db(db)
      logger.log "Dropping and recreating database: #{db}"
      q("drop database `#{db}`")
      q("create database `#{db}` DEFAULT CHARACTER SET `utf8`") #force UTF8
    end

    def get_tables(db)
      table_array = []
      connection.query("USE #{db}")
      connection.query("show tables").each do |row|
        table_array << row.values[0]
      end
      table_array
    end

    def frequency_check(db, table, forklift_data_table, frequency=nil)
      return true if frequency.nil?
      timestamps = q("select unix_timestamp(`created_at`) as 'time' from `#{db}`.`#{forklift_data_table}` where `name` =  '#{table}' and type='extraction'")
      return true if timestamps.nil?
      return true if timestamps.to_i + frequency <= Time.new.to_i
      return false
    end

    private 

    def build_remote_insert_row(row, db, destination_table_name)
      keys = []
      values = []
      row.each do |k,v|
        keys << "`#{k}`"
        if v.nil?
          values << "NULL"
        else
          v.gsub!('"','\"')
          values << "\"#{v}\""
        end
      end
      sql = "insert into `#{db}`.`#{destination_table_name}` (#{keys.join(",")}) values (#{values.join(",")})"
      sql
    end

    def generate_name(db, table, to_prefix)
      if to_prefix == false
        return table
      else
        return "#{db}_#{table}"
      end
    end

    def hash_count(h)
      count = 0
      return 0 if h.nil?
      h.each do |k,v|
        count = count + 1
      end
      count
    end

  end
end