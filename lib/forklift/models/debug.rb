module Forklift
  module Debug

    def self.debug?
      return true if ARGV.include?("--debug")
      return true if ARGV.include?("-debug")
      return false
    end

  end
end