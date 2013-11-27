module Forklift
  class Utils

    def self.class_name_from_file(file)
      klass = ""
      words = file.split("/").last.split(".").first.split("_")
      words.each do |word|
        klass << word.capitalize
      end
      klass
    end

    def self.name_from_file(file)
      file.split("/").last.split(".").first
    end

  end
end