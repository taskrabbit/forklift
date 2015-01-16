require 'elasticsearch'

module Forklift
  module Connection
    class Elasticsearch < Forklift::Base::Connection

      def initialize(config, forklift)
        @config = config
        @forklift = forklift
      end

      def config
        @config
      end

      def forklift
        @forklift
      end

      def connect 
        @client = ::Elasticsearch::Client.new(config)
      end

      def disconnect
        @client = nil
      end

      def read(index, query, looping=true, from=0, size=forklift.config[:batch_size])
        offset = 0
        loop_count = 0

        while (looping == true || loop_count == 0)
          data = []
          prepared_query = query
          prepared_query[:from] = from + offset
          prepared_query[:size] = size

          forklift.logger.debug "    ELASTICSEARCH: #{query.to_json}"
          results = client.search( { index: index, body: prepared_query } )
          results["hits"]["hits"].each do |hit|
            data << hit["_source"]
          end

          data.map{|l| l.symbolize_keys! }

          if block_given?
            yield data
          else
            return data
          end

          looping = false if results["hits"]["hits"].length == 0
          offset = offset + size
          loop_count = loop_count + 1
        end
      end

      def write(data, index, update=false, type='forklift', primary_key=:id)
        data.map{|l| l.symbolize_keys! }

        data.each do |d|
          object = {
            index:  index,
            body:   d,
            type:   type,
          }
          object[:id] = d[primary_key] if ( !d[primary_key].nil? && update == true )

          forklift.logger.debug "    ELASTICSEARCH (store): #{object.to_json}"
          client.index object
        end
        client.indices.refresh({ index: index })
      end

      def delete_index(index)
        forklift.logger.debug "    ELASTICSEARCH (delete index): #{index}"
        client.indices.delete({ index: index }) if client.indices.exists({ index: index })
      end

      private

      #/private

    end
  end
end
