require 'csv'
require 'fileutils'

module Forklift
  module Connection
    class Csv < Forklift::Base::Connection

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

      def read(size=1000)
        data = []
        CSV.foreach(config[:file], headers: true, converters: :all) do |row|
          data << row.to_hash.symbolize_keys
          if(data.length == size)
            if block_given?
              yield data
              data = []
            else
              return data
            end
          end
        end

        if block_given?
          yield data
        else
          return data
        end
      end

      def write(data, append=true)
        if (append == false)
          FileUtils.rm(config[:file], {force: true})
        end

        if( !File.exists?(config[:file]) )
          keys = data.first.keys
          row = {}
          keys.each do |k|
            row[k] = k
          end
          data = [row] + data
        end

        CSV.open(config[:file],'a') do |file|
          data.each do |row|
            file << row.values
          end
        end

      end

      private

      #/private

    end
  end
end
