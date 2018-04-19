module Forklift
  module Patterns
    class Psql
      class<<self
        def detect_primary_key_or_default(source, from_table)
          source.q("SHOW INDEX FROM `#{source.current_database}`.`#{from_table}` WHERE key_name = 'PRIMARY';").try(:first).try(:[], :Column_name).try(:to_sym) || :id
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

      end
    end
  end
end
