require 'mysql2'
require 'open3'

module Forklift
  module Connection
    class Mysql < Forklift::Base::Connection
      def connect
        @client = Mysql2::Client.new(config)
        q("USE `#{config[:database]}`")
      end

      def disconnect
        @client.close
      end

      def default_matcher
        :updated_at
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

        while ( looping == true || loop_count == 0 )
          data = []
          prepared_query = query
          if prepared_query.downcase.include?("select") && !prepared_query.downcase.include?("limit")
            prepared_query = "#{prepared_query} LIMIT #{offset}, #{limit}"
          end
          response = q(prepared_query)
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

      def write(rows, table, to_update=true, database=current_database, primary_key=:id, lazy=true, crash_on_extral_col=false)
        if tables.include? table
          ensure_row_types(rows, table, database)
        elsif(lazy == true && rows.length > 0)
          lazy_table_create(table, rows, database, primary_key)
        end

        if rows.length > 0
          columns = columns(table, database)
          rows.each do |row|
            if crash_on_extral_col == false
              row.each do |column, value|
                unless columns.include?(column)
                  q("ALTER TABLE `#{database}`.`#{table}` ADD `#{column}` #{sql_type(value)}  NULL  DEFAULT NULL;")
                  columns = columns(table, database)
                end
              end
            end
          end

          insert_values = []
          delete_keys = []
          rows.map do |row|
            delete_keys << row[primary_key] if to_update && row[primary_key].present?
            insert_values << safe_values(columns, row)
          end

          unless delete_keys.empty?
            q(%{DELETE FROM `#{database}`.`#{table}` WHERE `#{primary_key}` IN (#{delete_keys.join(',')})})
          end

          begin
            q(%{INSERT INTO `#{database}`.`#{table}` (#{safe_columns(columns)}) VALUES #{insert_values.join(',')}})
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

          forklift.logger.log "wrote #{rows.length} rows to `#{database}`.`#{table}`"
        end
      end

      def lazy_table_create(table, data, database=current_database, primary_key=:id, matcher=default_matcher)
        keys = {}
        data.each do |item|
          item.each do |k,v|
            keys[k] = sql_type(v) if (keys[k].nil? || keys[k] == sql_type(nil))
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
        col_defn << "KEY `#{matcher}` (`#{matcher}`)" if keys.include?(matcher)

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

      def read_since(table, since, matcher=default_matcher, database=current_database, limit=forklift.config[:batch_size])
        query = "SELECT * FROM `#{database}`.`#{table}` WHERE `#{matcher}` >= '#{since.to_s(:db)}' ORDER BY `#{matcher}` ASC"
        self.read(query, database, true, limit){|data|
          if block_given?
            yield data
          else
            return data
          end
        }
      end

      def max_timestamp(table, matcher=default_matcher, database=current_database)
        return Time.at(0) unless tables.include?(table)
        last_copied_row = read("SELECT MAX(`#{matcher}`) AS \"#{matcher}\" FROM `#{database}`.`#{table}`")[0]
        if ( last_copied_row.nil? || last_copied_row[matcher].nil? )
          Time.at(0)
        else
          last_copied_row[matcher]
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
        @_current_database ||= q("SELECT DATABASE() AS 'db'").first[:db]
      end

      def count(table, database=current_database)
        q("SELECT COUNT(1) AS \"count\" FROM `#{database}`.`#{table}`").first[:count]
      end

      def truncate!(table, database=current_database)
        q("TRUNCATE TABLE `#{database}`.`#{table}`")
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
        read("DESCRIBE `#{database}`.`#{table}`").each do |row|
          cols  << row[:Field].to_sym
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
        return client.query(query, {symbolize_keys: true}.merge(options))
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

      def safe_values(columns, row)
        "(" + columns.map do |column|
          v = row[column]
          case v
          when String, Symbol then %{"#{Mysql2::Client.escape(v.to_s)}"}
          when Date, Time, DateTime then %{"#{v.to_s(:db)}"}
          when Fixnum then v
          when Float, BigDecimal then v.to_f
          else 'NULL'
          end
        end.compact.join(', ') + ")"
      end

      #/private

    end
  end
end
