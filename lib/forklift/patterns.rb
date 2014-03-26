module Forklift
  module Patterns

    def self.mysql_optimistic_import(source, destination)
      source.tables.each do |table|
        if( source.columns(table).include?(source.default_matcher) && destination.tables.include?(table) )
          since = destination.max_timestamp(table)
          source.read_since(table, since){ |data| destination.write(data, table) }
        else
          destination.truncate table
          source.read("select * from #{table}"){ |data| destination.write(data, table) }
        end
      end
    end

  end
end
