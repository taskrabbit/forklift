require 'mysql2'
require 'open3'

module Forklift
  module Connection
    class Mysql < Forklift::Base::Connection

      def initialize(config, forklift)
        @config = config
        @forklift = forklift
      end

      def connect
        @client = Mysql2::Client.new(@config)
      end

      def disconnect
        @client.close
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

      def rename(table, new_table, database=current_database, new_database=current_database)
        q("RENAME TABLE `#{database}`.`#{table}` TO `#{new_database}`.`#{new_table}`")
      end

      def read(query, database=current_database, looping=true, limit=forklift.config[:batch_size], offset=0)
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

            if crash_on_extral_col == false
              d.each do |k,v|
                unless columns.include?(k.to_s)
                  q("ALTER TABLE `#{database}`.`#{table}` ADD `#{k}` #{sql_type(v)}  NULL  DEFAULT NULL;")
                  columns = columns(table, database)
                end
              end
            end
          end

          insert_q = "INSERT INTO `#{database}`.`#{table}` (#{safe_columns(columns)}) VALUES "
          delete_q = "DELETE FROM `#{database}`.`#{table}` WHERE `#{primary_key}` IN "
          delete_keys = []
          data.each do |d|
            if(to_update == true && !d[primary_key.to_sym].nil?)
              delete_keys << d[primary_key.to_sym]
            end
            insert_q << safe_values(columns, d)
            insert_q << ","
          end

          if delete_keys.length > 0
            delete_q << "(#{delete_keys.join(',')})"
            q(delete_q)
          end
          insert_q = insert_q[0...-1]

          begin
            q(insert_q)
          rescue Mysql2::Error => ex
            # UTF8 Safety.  Open a PR if you don't want UTF8 data...
            # https://github.com/taskrabbit/demoji
            raise ex unless ex.message.match /Incorrect string value:/
            safer_insert_q = ""
            for i in (0...insert_q.length)
              char = insert_q[i]
              char = '???' if char.ord > forklift.config[:char_bytecode_max]
              safer_insert_q << char
            end
            q(safer_insert_q)
          end

          forklift.logger.log "wrote #{data.length} rows to `#{database}`.`#{table}`"
        end
      end

      def lazy_table_create(table, data, database=current_database, primary_key='id', matcher=default_matcher)
        keys = {}
        data.each do |item|
          item.each do |k,v|
            keys[k.to_s] = sql_type(v) if (keys[k.to_s].nil? || keys[k.to_s] == sql_type(nil))
          end
        end
        keys[primary_key] = 'bigint(20)' unless keys.has_key?(primary_key)

        col_defn = keys.map do |col, type|
          if col == primary_key
            "`#{col}` #{type} NOT NULL AUTO_INCREMENT"
          else
            "`#{col}` #{type} DEFAULT NULL"
          end
        end
        col_defn << "PRIMARY KEY (`#{primary_key}`)"
        col_defn << "KEY `#{matcher}` (`#{matcher}`)" if keys.include?(matcher.to_sym)

        command = <<-EOS
        CREATE TABLE `#{database}`.`#{table}` (
          #{col_defn.join(', ')}
        )
        EOS

        q(command)
        forklift.logger.log "lazy-created table `#{database}`.`#{table}`"
      end

      def sql_type(v)
        return "bigint(20)"   if v.class == Fixnum
        return "float"        if v.class == Float
        return "float"        if v.class == BigDecimal
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
        @_current_database ||= q("select database() as 'db'").first['db']
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

      def columns(table, database=current_database, return_types=false)
        cols = []
        types = []
        read("describe `#{database}`.`#{table}`").each do |row|
          cols  << row[:Field]
          types << row[:Type]
        end
        return cols if return_types == false
        return cols, types
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
        delim = ';'
        body.split(/^(delimiter\s+.*)$/i).each do |section|
          if section =~ /^delimiter/i
            delim = section[/^delimiter\s+(.+)$/i,1]
            next
          end

          lines = section.split(delim)
          lines.each do |line|
            line.strip!
            q(line) if line.length > 0
          end
        end
      end

      def q(query, options={})
        forklift.logger.debug "\tSQL[#{config[:database]}]: #{query}"
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
              forklift.logger.log alter_sql
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

      def safe_values(columns, d)
        a = []
        sym_cols = columns.map { |s| s.to_sym }
        sym_cols.each do |c|
          part = "NULL"
          v = d[c]
          unless v.nil?
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
            elsif( [::Float, ::BigDecimal].include?(v.class) )
              part = v.to_f
            end
          end
          a << part
        end
        return "( #{a.join(', ')} )"
      end

      #/private

    end
  end
end
