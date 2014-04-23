module Forklift
  module Patterns
    class Mysql

      def self.pipe(source, from_table, destination, to_table)
        start = Time.new.to_i
        from_db = source.current_database 
        to_db = destination.current_database 
        source.forklift.logger.log("mysql pipe: `#{from_db}`.`#{from_table}` => `#{to_db}`.`#{to_table}`")
        source.q("drop table if exists `#{to_db}`.`#{to_table}`")
        source.q("create table `#{to_db}`.`#{to_table}` like `#{from_db}`.`#{from_table}`")
        source.q("insert into `#{to_db}`.`#{to_table}` select * from `#{from_db}`.`#{from_table}`")
        delta = Time.new.to_i - start
        source.forklift.logger.log("  ^ moved #{destination.count(to_table, to_db)} rows in #{delta}s")
      end

      def self.incremental_pipe(source, from_table, destination, to_table, matcher=source.default_matcher, primary_key='id')
        start = Time.new.to_i
        from_db = source.current_database 
        to_db = destination.current_database 
        source.forklift.logger.log("mysql incremental_pipe: `#{from_db}`.`#{from_table}` => `#{to_db}`.`#{to_table}`")
        source.q("create table if not exists `#{to_db}`.`#{to_table}` like `#{from_db}`.`#{from_table}`")

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
          source.read("select `#{primary_key}` from `#{from_db}`.`#{from_table}` where `#{matcher}` > \"#{latest_timestamp}\" order by `#{matcher}`") do |stale_rows|
            if stale_rows.length > 0
              # Delete these ids from to_table.
              # If the ids are stale, then they'll be deleted. If they're new, they won't exist, and nothing will happen.
              stale_ids = stale_rows.map { |row| row[primary_key.to_sym] }.join(',')
              source.q("delete from `#{to_db}`.`#{to_table}` where `#{primary_key}` in (#{stale_ids})")
              source.forklift.logger.log("  ^ deleted up to #{stale_rows.length} stale rows from `#{to_db}`.`#{to_table}`")
            end
          end
        end

        # Do the insert into to_table
        destination.q("insert into `#{to_db}`.`#{to_table}` select * from `#{from_db}`.`#{from_table}` where `#{matcher}` > \"#{latest_timestamp}\" order by `#{matcher}`")
        delta = Time.new.to_i - start
        new_count = destination.count(to_table, to_db) - original_count
        source.forklift.logger.log("  ^ created #{new_count} new rows in #{delta}s")
      end

      def self.optimistic_pipe(source, from_table, destination, to_table, matcher=source.default_matcher, primary_key='id')
        from_db = source.current_database 
        to_db = destination.current_database 
        if self.can_incremental_pipe?(source, from_table, destination, to_table, matcher)
          incremental_pipe(source, from_table, destination, to_table, matcher, primary_key)
        else
          pipe(source, from_table, destination, to_table)
        end
      end

      def self.can_incremental_pipe?(source, from_table, destination, to_table, matcher=source.default_matcher)
        a = source.tables.include?(from_table)
        b = source.columns(from_table, source.current_database).include?(matcher)
        c = destination.tables.include?(to_table)
        d = destination.columns(to_table, destination.current_database).include?(matcher)
        return (a && b && c && d)
      end

      ## When you are copying data to and from mysql 
      ## An implementation of "pipe" for remote databases
      def self.mysql_optimistic_import(source, destination, matcher=source.default_matcher)
        source.tables.each do |table|
          if( source.columns(table).include?(matcher) && destination.tables.include?(table) && destination.columns(table).include?(matcher) )
            since = destination.max_timestamp(table)
            source.read_since(table, since){ |data| destination.write(data, table) }
          else
            # destination.truncate table
            destination.drop! table if destination.tables.include?(table)
            source.read("select * from #{table}"){ |data| destination.write(data, table) }
          end
        end
      end

    end
  end
end
