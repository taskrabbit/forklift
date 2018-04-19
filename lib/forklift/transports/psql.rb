require 'delegate'
require 'zlib'

module Forklift
  module Connection
    class Psql < Forklift::Base::Connection
      def initialize(config, forklift)
        begin
          require 'pg' unless defined?(PG)
        rescue LoadError
          raise "To use the postgres connection you must add 'pg' to your Gemfile"
        end
        super(config, forklift)
      end

      def connect
        @client ||= PG::Connection.new(config)
        q('set search_path=public')
      end

      def disconnect
        client.close
      end

      def default_matcher
        'updated_at'
      end

      def drop!(table)
        q("DROP TABLE IF EXISTS #{quote_ident(table)}")
      end

      def rename(table, new_table)
        q("ALTER TABLE #{quote_ident(table)} RENAME TO #{quote_ident(new_table)}")
      end

      def read(query, database: current_database, looping: true, limit: forklift.config[:batch_size], offset: 0)
        page = 1
        loop do
          result = q(paginate_query(query, page, limit))

          block_given? ? yield(result) : (return result)
          return result if result.num_tuples < limit || !looping
          page += 1
        end
      end

      def write(rows, table, to_update=true, database=current_database, primary_key=:id, lazy=true, crash_on_extral_col=false)

        if tables.include? table
          ensure_row_types(rows, table, database)
        elsif lazy && rows.length > 0
          lazy_table_create(table, rows, database, primary_key)
        end

        ids = []
        if rows.length > 0
          insert_values = []
          delete_keys = []
          columns = columns(table, database)
          rows.each do |row|
            ids << row[primary_key]
            delete_keys << safe_values([primary_key], row) if to_update && !row[primary_key].nil?

            insert_values << safe_values(columns, row)
          end

          unless delete_keys.empty?
            q(%{DELETE FROM #{quote_ident(table)} WHERE #{quote_ident(primary_key)} IN (#{delete_keys.join(',')})})
          end


          q(%{INSERT INTO #{quote_ident(table)} (#{safe_columns(columns)}) VALUES #{insert_values.join(',')}})
          forklift.logger.log "wrote #{rows.length} rows to `#{database}`.`#{table}`"
        end
      end

      # @todo
      def lazy_table_create(table, data, database=current_database, primary_key=:id, matcher=default_matcher)
        raise NotImplementedError.new
      end

      # @todo
      def sql_type(v)
        raise NotImplementedError.new
      end

      def read_since(table, since, matcher=default_matcher, database=current_database, limit=forklift.config[:batch_size])
        query = %{SELECT * FROM #{quote_ident(table)} WHERE #{quote_ident(matcher)} >= #{client.escape_literal(since)} ORDER BY #{quote_ident(matcher)} ASC}
        self.read(query, database: database, looping: true, limit: limit) do |rows|
          if block_given?
            yield rows
          else
            return rows
          end
        end
      end

      def max_timestamp(table, matcher=default_matcher)
        row = q(%{SELECT max(#{quote_ident(matcher)}) AS 'matcher' FROM #{quote_ident(table)}}).first
        (row && row['matcher']) || Time.at(0)
      end

      def tables
        table_list = []

        read(%{SELECT table_name AS "table_name" FROM information_schema.tables WHERE table_schema = 'public'}) do |result|
          table_list << result.map{|r| r['table_name']}
        end
        table_list.flatten.compact
      end

      def current_database
        client.db
      end

      def count(table)
        q(%{SELECT count(1) AS "count" FROM #{quote_ident(table)}})[0][:count].to_i
      end

      def truncate!(table)
        q("TRUNCATE TABLE #{quote_ident(table)}")
      end

      def truncate(table)
        begin
          self.truncate!(table)
        rescue Exception => e
          forklift.logger.debug e
        end
      end

      def columns(table, database=current_database, return_types=false)
        columns = {}
        read(%{SELECT column_name, data_type, character_maximum_length FROM "information_schema"."columns" WHERE table_name='#{table}'}) do |rows|
          rows.each do |row|
            type = case row[:data_type]
                     when 'character varying' then "varchar(#{row[:character_maximum_length]})"
                     else row[:data_type]
                   end
            columns[row[:column_name].to_sym] = type
          end
        end
        return_types ? columns : columns.keys
      end

      def dump(file, options=[])
        dburl = URI::Generic.new('postgresql', "#{client.user}:#{config[:password]}", (client.host || 'localhost'), client.port, nil, "/#{client.db}", nil, nil, nil)
        cmd = %{pg_dump --dbname #{dburl.to_s} -Fp #{options.join(' ')} | gzip > #{file}}
        forklift.logger.log "Dumping #{client.db} to #{file}"
        forklift.logger.debug cmd

        Open3.popen3(cmd) do |stdin, stdout, stderr|
          stdout = stdout.readlines
          stderr = stderr.readlines
          if stderr.length > 0
            raise "  > Dump error: #{stderr.join(" ")}"
          else
            forklift.logger.log "  > Dump complete"
          end
        end
      end

      def exec_script(path)
        body = if path[/\.gz$/]
                 Zlib::GzipReader.open(path).read
               else
                 File.read(path)
               end
        q(body)
      end

      def safe_values(columns, row)

        "(" + columns.map do |column|
          v = row[column]
          case v
            when String, Symbol then %{'#{PG::Connection.escape_string(v.to_s)}'}
            when Date, Time, DateTime then %{"#{v.to_s(:db)}"}
            when Fixnum then v
            when Float, BigDecimal then v.to_f
            else 'NULL'
          end
        end.compact.join(', ') + ")"
      end

      def safe_columns(cols)
        return cols.join(', ')
      end

      def q(query, options={})
        forklift.logger.debug "\tSQL[#{config[:database]}]: #{query}"
        client.exec('set search_path=public')
        Result.new(client.exec(query))
      end

      class Result < SimpleDelegator
        def initialize(pg_result)
          @pg_result = pg_result
          super(pg_result)
        end

        def [](idx)
          symbolize_row(@pg_result[idx])
        end

        def each
          @pg_result.each do |row|
            yield symbolize_row(row)
          end
        end

        def length
          @pg_result.ntuples
        end

        private
        def symbolize_row(row)
          row.inject({}) do |memo, (k,v)|
            memo[k.to_sym] = v
            memo
          end
        end
      end

      private
      def ensure_row_types(rows, table, database=current_database)
        columns = columns(table, database)
        rows.each do |row|
          row.each do |column, value|
            unless columns.include?(column)
              q(%{ALTER TABLE #{quote_ident(table)} ADD #{quote_ident(column)} #{sql_type(value)} NULL DEFAULT NULL})
              columns = columns(table, database)
            end
          end
        end
      end

      def paginate_query(query, page, page_size)
        offset = (page-1) * page_size
        [query, "ORDER BY 1", "LIMIT #{page_size} OFFSET #{offset}"].join(' ')
      end

      def quote_ident(table)
        PG::Connection.quote_ident(table.to_s)
      end
    end
  end
end
