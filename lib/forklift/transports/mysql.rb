require 'mysql2'
require 'open3'

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

      def default_matcher
        'updated_at'
      end

      def drop!(table, database=current_database)
        q("DROP table `#{database}`.`#{table}`");
      end

      def read(query, database=current_database, looping=true, limit=1000, offset=0)
        loop_count = 0
        # TODO: Detect limit/offset already present in query
        q("USE `#{database}`")

        while ( looping == true || loop_count == 0 )
          data = []
          prepared_query = query
          if prepared_query.downcase.include?("select") && !prepared_query.downcase.include?("limit")
            prepared_query = "#{prepared_query} LIMIT #{offset}, #{limit}"
          end
          response = q(prepared_query, symbolize_keys: true)
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
          loop_count = loop_count + 1
        end
      end

      def write(data, table, to_update=true, database=current_database, primary_key='id', lazy=true, crash_on_extral_col=false)
        data.map{|l| l.symbolize_keys! }

        if tables.include? table
          ensure_row_types(data, table, database)
        elsif(lazy == true && data.length > 0)
          lazy_table_create(table, data, database, primary_key)
        end

        if data.length > 0
          columns = columns(table, database)
          data.each do |d|
            d = clean_to_columns(d, columns) unless crash_on_extral_col == true
            if(to_update == true && !d[primary_key.to_sym].nil?)
              q("DELETE FROM `#{database}`.`#{table}` WHERE `#{primary_key}` = #{d[primary_key.to_sym]}")
            end
            insert_q = "INSERT INTO `#{database}`.`#{table}` (#{safe_columns(d.keys)}) VALUES (#{safe_values(d.values)});"
            q(insert_q)
          end
          forklift.logger.log "wrote #{data.length} rows to `#{database}`.`#{table}`"
        end
      end

      def lazy_table_create(table, data, database=current_database, primary_key='id', matcher=default_matcher)
        keys = {}
        data.each do |item|
          item.each do |k,v|
            keys[k] = sql_type(v) if ( keys[k].nil? && v.class != NilClass )
          end
        end

        data.first.each do |k,v|
          keys[k] = sql_type(v) if ( keys[k].nil? )
        end

        command = "CREATE TABLE `#{database}`.`#{table}` ( "
        command << " `#{primary_key}` bigint(20) NOT NULL AUTO_INCREMENT, " if ( data.first[primary_key.to_sym].nil? )
        keys.each do |col, type|
          command << " `#{col}` #{type} DEFAULT NULL, "
        end
        command << " PRIMARY KEY (`#{primary_key}`) "
        command << " , KEY `#{matcher}` (`#{matcher}`) " if keys.include?(matcher.to_sym)
        command << " ) "

        q(command)
        forklift.logger.log "lazy-created table `#{database}`.`#{table}`"
      end

      def sql_type(v)
        return "bigint(20)"   if v.class == Fixnum
        return "float"        if v.class == Float
        return "date"         if v.class == Date
        return "datetime"     if v.class == Time
        return "datetime"     if v.class == DateTime
        return "varchar(255)" if v.class == Symbol
        return "tinyint(1)"   if v.class == TrueClass
        return "tinyint(1)"   if v.class == FalseClass
        return "text"         if v.class == String
        return "varchar(0)"   if v.class == NilClass
        return "text"         # catchall
      end

      def read_since(table, since, matcher=default_matcher, database=current_database)
        query = "select * from `#{database}`.`#{table}` where `#{matcher}` >= '#{since}' order by `#{matcher}` asc"
        self.read(query, database){|data|
          if block_given?
            yield data
          else
            return data
          end
        }
      end

      def max_timestamp(table, matcher=default_matcher, database=current_database)
        last_copied_row = read("select max(`#{matcher}`) as \"#{matcher}\" from `#{database}`.`#{table}`")[0]
        if ( last_copied_row.nil? || last_copied_row[matcher.to_sym].nil? )
          latest_timestamp = '1970-01-01 00:00'
        else
          return last_copied_row[matcher.to_sym].to_s(:db)
        end
      end

      def tables
        t = []
        client.query("show tables").each do |row|
          t << row.values[0]
        end
        t
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

      def truncate(table, database=current_database)
        begin
          self.truncate!(table, database=current_database)
        rescue Exception => e
          forklift.logger.debug e
        end
      end

      def columns(table, database=current_database)
        cols = []
        read("describe `#{database}`.`#{table}`").each do |row|
          cols << row[:Field]
        end
        cols
      end

      def dump(file, options=[])
        # example options: 
        # options.push '--max_allowed_packet=512M'
        # options.push '--set-gtid-purged=OFF'
        cmd = "mysqldump"
        cmd << " -u#{config[:username]}" unless config[:username].nil?
        cmd << " -p#{config[:password]}" unless config[:password].nil?
        options.each do |o|
          cmd << " #{o} "
        end
        cmd << " #{config[:database]}"
        cmd << " | gzip > #{file}"
        forklift.logger.log "Dumping #{config['database']} to #{file}"
        forklift.logger.debug cmd
        
        stdin, stdout, stderr = Open3.popen3(cmd)
        stdout = stdout.readlines
        stderr = stderr.readlines
        if stderr.length > 0
          raise "  > Dump error: #{stderr.join(" ")}"
        else
          forklift.logger.log "  > Dump complete"
        end
      end

      def exec_script(path)
        body = File.read(path)
        lines = body.split(';')
        lines.each do |line|
          line.strip!
          q(line) if line.length > 0
        end
      end

      def q(query, options={})
        forklift.logger.debug "    SQL: #{query}"
        return client.query(query, options)
      end

      private

      def ensure_row_types(data, table, database=current_database)
        read("describe `#{database}`.`#{table}`").each do |row|
          if row[:Type] == 'varchar(0)'

            value = nil
            data.each do |r|
              if ( !r[row[:Field].to_sym].nil? )
                value = r[row[:Field].to_sym]
                break
              end
            end

            if !value.nil?
              sql_type = sql_type(value)
              alter_sql = "ALTER TABLE `#{database}`.`#{table}` CHANGE `#{row[:Field]}` `#{row[:Field]}` #{sql_type};"
              puts alter_sql
              q(alter_sql)
            end

          end
        end 
      end

      def safe_columns(cols)
        a = []
        cols.each do |c|
          a << "`#{c}`"
        end
        return a.join(', ')
      end

      def clean_to_columns(row, columns)
        r = {}
        row.each do |k,v|
          r[k] = row[k] if columns.include?(k.to_s)
        end
        r
      end

      def safe_values(values)
        a = []
        values.each do |v|
          part = "NULL"
          if( [::String, ::Symbol].include?(v.class) )
            s = v.to_s
            s.gsub!('\\') { '\\\\' }
            s.gsub!('\"', '\/"')
            s.gsub!('"', '\"')
            part = "\"#{s}\""
          elsif( [::Date, ::Time, ::DateTime].include?(v.class) )
            s = v.to_s(:db)
            part = "\"#{s}\""
          elsif( [::Fixnum].include?(v.class) )
            part = v
          elsif( [::Float].include?(v.class) )
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
