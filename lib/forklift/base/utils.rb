require 'yaml'
require 'erb'

module Forklift
  module Base
    class Utils

      def load_yml(file)
        YAML.load(ERB.new(File.read(file)).result)
      end

      def class_name_from_file(file)
        klass = ""
        words = file.split("/").last.split(".").first.split("_")
        words.each do |word|
          klass << word.capitalize
        end
        klass
      end

      def symbolize_keys(h)
        h.keys.each do |key|
          h[(key.to_sym rescue key) || key] = h.delete(key)
        end
        h
      end

    end
  end
end
