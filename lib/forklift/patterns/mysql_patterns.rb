module Forklift
  module Patterns
    class Mysql
      class<<self
        # Moves rows from one table to another within a single database.
        # This assumes that we can directly insert to the destination from
        # the source. If you are moving data between separate MySQL servers
        # take a look at {Forklift::Patterns::Mysql.mysql_import}.
        #
        # It's worth noting that the move happens by way of a working table
        # that is cleared, filled and then renamed to the `to_table` after
        # `to_table` is dropped.
        #
        # @param source [Forklift::Connection::Mysql] the source database
        #   connection
        # @param from_table [String] the table name that has the rows you
        #   want to move
        # @param destination [Forklift::Connection::Mysql] the destination
        #   database connection. This must be the same MySQL server as the
        #   source
        # @param to_table [String] the table name where the new rows will
        #   be inserted in to
        # @param options [Hash]
        # @option options [String] :tmp_table ('_forklift_tmp') The working
        #   table name that ultimately replaces `to_table`
        #
        # @see .mysql_import
        def pipe(source, from_table, destination, to_table, options={})
          start = Time.new.to_i
          from_db = source.current_database
          to_db = destination.current_database
          tmp_table = options[:tmp_table] || '_forklift_tmp'
          source.forklift.logger.log("mysql pipe: `#{from_db}`.`#{from_table}` => `#{to_db}`.`#{to_table}`")

          source.q("DROP TABLE IF EXISTS `#{to_db}`.`#{tmp_table}`")
          source.q("CREATE TABLE `#{to_db}`.`#{tmp_table}` LIKE `#{from_db}`.`#{from_table}`")
          source.q("INSERT INTO `#{to_db}`.`#{tmp_table}` SELECT * FROM `#{from_db}`.`#{from_table}`")
          source.q("DROP TABLE IF EXISTS `#{to_db}`.`#{to_table}`")
          source.q("RENAME TABLE `#{to_db}`.`#{tmp_table}` TO `#{to_db}`.`#{to_table}`")

          delta = Time.new.to_i - start
          source.forklift.logger.log("  ^ moved #{destination.count(to_table, to_db)} rows in #{delta}s")
        end

        # Pipe rows from one table to another within the same database
        # (see .pipe). This is the incremental version of the {.pipe}
        # pattern and will only move records whose `matcher` column is
        # newer than the maximum in the destination table.
        #
        # @param (see .pipe)
        # @option options [String] :matcher ('updated_at') The datetime
        #   column used to find the "newest" records in the `from_table`
        # @option options [String] :primary_key ('id') The column to use
        #   to determine if the row should be updated or inserted. Updates
        #   are performed by deleting the old version of the row and
        #   reinserting the new, updated row.
        #
        # @see .mysql_incremental_import
        # @see .pipe
        def incremental_pipe(source, from_table, destination, to_table, options={})
          start = Time.new.to_i
          from_db = source.current_database
          to_db = destination.current_database
          matcher = options[:matcher] || source.default_matcher
          primary_key = options[:primary_key] || :id
          source.forklift.logger.log("mysql incremental_pipe: `#{from_db}`.`#{from_table}` => `#{to_db}`.`#{to_table}`")
          source.q("CREATE TABLE IF NOT EXISTS `#{to_db}`.`#{to_table}` LIKE `#{from_db}`.`#{from_table}`")

          # Count the number of rows in to_table
          original_count = source.count(to_table, to_db)

          # Find the latest/max/newest timestamp from the final table
          # in order to determine the last copied row.
          latest_timestamp = source.max_timestamp(to_table, matcher, to_db)

          # If to_table has existing rows, ensure none of them are "stale."
          # A stale row in to_table means a previously copied row was
          # updated in from_table, so let's delete it from the to_table
          # so we can get a fresh copy of that row.
          if original_count > 0
            # Get the ids of rows in from_table that are newer than the newest row in to_table.
            # Some of these rows could either be a) stale or b) new.
            source.read("SELECT `#{primary_key}` FROM `#{from_db}`.`#{from_table}` WHERE `#{matcher}` > \"#{latest_timestamp}\" ORDER BY `#{matcher}`") do |stale_rows|
              if stale_rows.length > 0
                # Delete these ids from to_table.
                # If the ids are stale, then they'll be deleted. If they're new, they won't exist, and nothing will happen.
                stale_ids = stale_rows.map { |row| row[primary_key] }.join(',')
                source.q("DELETE FROM `#{to_db}`.`#{to_table}` WHERE `#{primary_key}` IN (#{stale_ids})")
                source.forklift.logger.log("  ^ deleted up to #{stale_rows.length} stale rows from `#{to_db}`.`#{to_table}`")
              end
            end
          end

          # Do the insert into to_table
          destination.q("INSERT INTO `#{to_db}`.`#{to_table}` SELECT * FROM `#{from_db}`.`#{from_table}` WHERE `#{matcher}` > \"#{latest_timestamp.to_s(:db)}\" ORDER BY `#{matcher}`")
          delta = Time.new.to_i - start
          new_count = destination.count(to_table, to_db) - original_count
          source.forklift.logger.log("  ^ created #{new_count} new rows in #{delta}s")
        end

        # Attempt an {.incremental_pipe} and fall back to a {.pipe} if unable
        # to run incrementally.
        #
        # @param (see .pipe)
        # @option (see .pipe)
        # @option (see .incremental_pipe)
        #
        # @see .pipe
        # @see .incremental_pipe
        def optimistic_pipe(source, from_table, destination, to_table, options={})
          from_db = source.current_database
          to_db = destination.current_database
          if self.can_incremental_pipe?(source, from_table, destination, to_table, options)
            begin
              incremental_pipe(source, from_table, destination, to_table, options)
            rescue Exception => e
              source.forklift.logger.log("! incremental_pipe failure on #{from_table} => #{to_table}: #{e} ")
              source.forklift.logger.log("! falling back to pipe...")
              pipe(source, from_table, destination, to_table)
            end
          else
            pipe(source, from_table, destination, to_table, options)
          end
        end

        # Attempt a {.mysql_incremental_import} and fall back to {.mysql_import}
        #
        # @param (see .mysql_import)
        # @option (see .mysql_import)
        # @option (see .mysql_incremental_import)
        #
        # @see .mysql_import
        # @see .mysql_incremental_import
        def mysql_optimistic_import(source, from_table, destination, to_table, options={})
          if self.can_incremental_import?(source, from_table, destination, to_table, options)
            begin
              self.mysql_incremental_import(source, from_table, destination, to_table, options)
            rescue Exception => e
              source.forklift.logger.log("! incremental import failure on #{from_table} => #{to_table}: #{e} ")
              source.forklift.logger.log("! falling back to import...")
              self.mysql_import(source, from_table, destination, to_table, options)
            end
          else
            self.mysql_import(source, from_table, destination, to_table, options)
          end
        end

        def detect_primary_key_or_default(source, from_table)
          source.q("SHOW INDEX FROM `#{source.current_database}`.`#{from_table}` WHERE key_name = 'PRIMARY';").try(:first).try(:[], :Column_name).try(:to_sym) || :id
        end

        # Import table from one mysql instance to another incrementally.
        #
        # @param (see .mysql_import
        # @option options [String] :matcher ('updated_at') The datetime
        #   column used to find the "newest" records in the `from_table`
        #
        # @see .mysql_import
        # @see .incremental_pipe
        def mysql_incremental_import(source, from_table, destination, to_table, options={})
          matcher =  options[:matcher] || source.default_matcher
          primary_key = detect_primary_key_or_default(source, from_table)

          since = destination.max_timestamp(to_table, matcher)
          source.read_since(from_table, since, matcher){ |data| destination.write(data, to_table, true, destination.current_database, primary_key) }
        end

        # Pull a table from the `source` database in to the `destination` database.
        # This is an upoptimized version of {.pipe}. Unlike {.pipe} this method can
        # pull records from one mysql instance in to another. The `to_table` at the
        # `destination` database will get a `DROP` if it exists.
        #
        # @param (see .pipe)
        #
        # @return
        #
        # @see .pipe
        def mysql_import(source, from_table, destination, to_table, options={})
          primary_key = detect_primary_key_or_default(source, from_table)

          # destination.truncate table
          destination.drop! to_table if destination.tables.include?(to_table)
          source.read("SELECT * FROM #{from_table}"){ |data| destination.write(data, to_table, true, destination.current_database, primary_key) }
        end

        # The high water method will stub a row in all tables with a `default_matcher` column prentending to have a record from `time`
        # This enabled partial forklift funs which will only extract data "later than X"
        #
        # @todo assumes all columns have a default NULL setting
        def write_high_water_mark(db, time, matcher=db.default_matcher)
          db.tables.each do |table|
            columns, types = db.columns(table, db.current_database, true)
            if columns.include?(matcher)
              row = {}
              i = 0
              while( i < columns.length )
                if(columns[i] == matcher)
                  row[columns[i]] = time.to_s(:db)
                elsif( types[i] =~ /text/ )
                  row[columns[i]] = "~~stub~~" 
                elsif( types[i] =~ /varchar/  )
                  row[columns[i]] = "~~stub~~".to_sym
                elsif( types[i] =~ /float/ || types[i] =~ /int/ || types[i] =~ /decimal/ )
                  row[columns[i]] = 0
                elsif( types[i] =~ /datetime/ || types[i] =~ /timestamp/ )
                  row[columns[i]] = time.to_s(:db)
                elsif( types[i] =~ /date/ )
                  row[columns[i]] = time.to_s(:db).split(" ").first
                else
                  row[columns[i]] = "NULL"
                end
                i = i + 1
              end
              db.write([row], table)
            end
          end
        end

        # Tests if a particular pipe parameterization can be performed incrementally
        #
        # @param (see .incremental_pipe)
        #
        # @return [true|false]
        def can_incremental_pipe?(source, from_table, destination, to_table, options={})
          matcher = options[:matcher] || source.default_matcher
          return false unless source.tables.include?(from_table)
          return false unless destination.tables.include?(to_table)
          source_cols      = source.columns(from_table, source.current_database)
          destination_cols = destination.columns(to_table, destination.current_database)
          return false unless source_cols.include?(matcher)
          return false unless destination_cols.include?(matcher)
          source_cols.each do |source_col|
            return false unless destination_cols.include?(source_col)
          end
          destination_cols.each do |destination_col|
            return false unless source_cols.include?(destination_col)
          end
          true
        end

        # Tests if a particular import parameterization can be performed incrementally
        #
        # @param (see .mysql_incremental_import)
        #
        # @return [true|false]
        def can_incremental_import?(source, from_table, destination, to_table, options={})
          matcher = options[:matcher] || source.default_matcher
          source.columns(from_table).include?(matcher) && destination.tables.include?(to_table) && destination.columns(to_table).include?(matcher)
        end
      end
    end
  end
end
