viprequire 'yaml'
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

    end
  end
end