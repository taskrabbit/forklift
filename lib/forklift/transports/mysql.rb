require 'mysql2'
require 'awesome_print'

module Forklift
  module Connection
    class Mysql < Forklift::Base::Connection

      def initialize(config, forklift)
        @config = config
        @forklift = forklift
        @client = Mysql2::Client.new(config)
        # q("USE #{config['database']}")
      end

      def config
        @config
      end

      def forklift
        @forklift
      end

      def drop!(table, database=current_database)
        q("DROP table `#{database}`.`#{table}`");
      end

      def read(query, database=current_database, looping=true, limit=1000, offset=0)
        # TODO: Detect limit/offset already present in query
        q("USE `#{database}`")

        while looping == true
          data = []
          prepared_query = query
          if prepared_query.downcase.include?("select") && !prepared_query.downcase.include?("limit")
            prepared_query = "#{prepared_query} LIMIT #{offset}, #{limit}"
          end
          response = q(prepared_query, :symbolize_keys => true)
          response.each do |row|
            data << row
          end

          if block_given?
            yield data 
          else
            return data
          end
          
          offset = offset + limit
          looping = false if data.length == 0 
        end
      end

      def write(data, table, to_update=false, database=current_database, primary_key='id', lazy=true)
        if tables.include? table
          # all good, cary on
        elsif(lazy == true && data.length > 0)
          lazy_table_create(table, data.first, database, primary_key)
        end

        if data.length > 0
          data.each do |d|
            if(to_update == true && !d[primary_key.to_sym].nil?)
              q("DELETE FROM `#{database}`.`#{table}` WHERE `#{primary_key}` = #{d[primary_key.to_sym]}")
            end
            q("INSERT INTO `#{database}`.`#{table}` (#{safe_columns(d.keys)}) VALUES (#{safe_values(d.values)});")
          end
          forklift.logger.log "write #{data.length} rows to `#{database}`.`#{table}`"
        end
      end

      def lazy_table_create(table, item, database=current_database, primary_key='id')
        keys = {}
        item.each do |k,v|
          keys[k] = sql_type(v)
        end

        command = "CREATE TABLE `#{database}`.`#{table}` ( "
        command << " `#{primary_key}` int(11) NOT NULL AUTO_INCREMENT, "
        keys.each do |col, type|
          command << " `#{col}` #{type} DEFAULT NULL, "
        end
        command << " PRIMARY KEY (`#{primary_key}`) "
        command << " ) "

        q(command)
        forklift.logger.log "lazy-created table `#{database}`.`#{table}`"
      end

      def sql_type(v)
        return "int(11)"      if v.class == Fixnum
        return "float"        if v.class == Float
        return "date"         if v.class == Date
        return "datetime"     if v.class == Time
        return "varchar(255)" if v.class == Symbol
        return "tinyint(1)"   if v.class == TrueClass
        return "tinyint(1)"   if v.class == FalseClass
        return "text"         if v.class == String
        return "text"         if v.class == NilClass
        return "text"         # catchall
      end

      def pipe(from_table, from_db, to_table, to_db)
        start = Time.new.to_i
        forklift.logger.log("mysql pipe: `#{from_db}`.`#{from_table}` => `#{to_db}`.`#{to_table}`")
        q("drop table if exists `#{to_db}`.`#{to_table}`")
        q("create table `#{to_db}`.`#{to_table}` like `#{from_db}`.`#{from_table}`")
        q("insert into `#{to_db}`.`#{to_table}` select * from `#{from_db}`.`#{from_table}`")
        delta = Time.new.to_i - start
        forklift.logger.log("  ^ moved #{count(to_table, to_db)} rows in #{delta}s")
      end

      def incremental_pipe(from_table, from_db, to_table, to_db, matcher='updated_at', primary_key='id')
        start = Time.new.to_i
        forklift.logger.log("mysql incremental_pipe: `#{from_db}`.`#{from_table}` => `#{to_db}`.`#{to_table}`")
        q("create table if not exists `#{to_db}`.`#{to_table}` like `#{from_db}`.`#{from_table}`")
        last_coppied_row = read("select max(`#{matcher}`) as \"#{matcher}\" from `#{to_db}`.`#{to_table}`")[0]
        original_count = count(to_table, to_db)
        if ( last_coppied_row.nil? || last_coppied_row[matcher.to_sym].nil? )
          latest_timestamp = '1970-01-01 00:00'
        else
          latest_timestamp = last_coppied_row[matcher.to_sym].to_s(:db)
          read("select `#{primary_key}` from `#{from_db}`.`#{from_table}` where `#{matcher}` > \"#{latest_timestamp}\""){|old_rows| 
            old_rows.each do |row|
              #TODO: These can be batch-deleted in one command
              q("delete from `#{to_db}`.`#{to_table}` where `#{primary_key}` = #{row[primary_key.to_sym]}")
            end
            forklift.logger.log("  ^ deleted #{old_rows.count} stale rows")
          }
        end
        q("insert into `#{to_db}`.`#{to_table}` select * from `#{from_db}`.`#{from_table}` where `#{matcher}` > \"#{latest_timestamp}\"")
        delta = Time.new.to_i - start
        new_count =  count(to_table, to_db) - original_count
        forklift.logger.log("  ^ created #{new_count} new rows rows in #{delta}s")
      end

      def optomistic_pipe(from_db, from_table, to_db, to_table, matcher='updated_at', primary_key='id')
        if can_incremental_pipe?(from_table, from_db)
          incremental_pipe(from_table, from_db, to_table, to_db, matcher, primary_key)
        else
          pipe(from_table, from_db, to_table, to_db)
        end
      end

      def can_incremental_pipe?(from_table, from_db, matcher='updated_at')
        return true if columns(from_table, from_db).include?(matcher)
        return false
      end

      def tables
        tables = []
        client.query("show tables").each do |row|
          tables << row.values[0]
        end
        tables
      end

      def current_database
        q("select database() as 'db'").first['db']
      end

      def count(table, database=current_database)
        read("select count(1) as \"count\" from `#{database}`.`#{table}`")[0][:count]
      end

      def truncate!(table, database=current_database)
        q("truncate table `#{database}`.`#{table}`")
      end

      def columns(table, database=current_database)
        cols = []
        read("describe `#{database}`.`#{table}`").each do |row|
          cols << row[:Field]
        end
        cols
      end

      def dump(file)
        cmd = "mysqldump" 
        cmd << " -u#{config['username']}" unless config['username'].nil?
        cmd << " -p#{config['password']}" unless config['password'].nil?
        cmd << " --max_allowed_packet=512M"
        cmd << " #{config['database']}"
        cmd << " | gzip > #{file}"
        forklift.logger.log "Dumping #{config['database']} to #{file}"
        forklift.logger.debug cmd
        `#{cmd}`
        forklift.logger.log "  > Dump complete"
      end

      def exec_script(path)
        body = File.read(path)
        lines = body.split(';')
        lines.each do |line|
          line.strip!
          q(line) if line.length > 0
        end
      end

      private

      def q(query, options={})
        start = Time.new.to_i
        data = client.query(query, options)
        delta = Time.new.to_i - start
        forklift.logger.debug "    SQL: #{query} (#{delta}s)"
        return data
      end

      def safe_columns(cols)
        a = []
        cols.each do |c|
          a << "`#{c}`"
        end
        return a.join(', ')
      end

      def safe_values(values)
        a = []
        values.each do |v|
          part = "NULL"  
          if v.class == String
            v.gsub!('"', "\"")
            part = "\"#{v}\""
          elsif v.class == Number
            part = v.to_f
          end 
          a << part
        end
        return a.join(', ')
      end

      #/private

    end
  end
end