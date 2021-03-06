require 'forklift/version'

module Forklift

  lib = File.join(File.expand_path(File.dirname(__FILE__)), 'forklift')

  require "#{lib}/base/utils.rb"
  require "#{lib}/base/pid.rb"
  require "#{lib}/base/logger.rb"
  require "#{lib}/base/mailer.rb"
  require "#{lib}/base/connection.rb"

  Dir["#{lib}/transports/*.rb"].each {|file| require file }
  Dir["#{lib}/patterns/*.rb"].each {|file| require file }
  Dir["#{Dir.pwd}/transports/*.rb"].each {|file| require file } if File.directory?("#{Dir.pwd}/transports")
  Dir["#{Dir.pwd}/patterns/*.rb"].each {|file| require file } if File.directory?("#{Dir.pwd}/patterns")

  require "#{lib}/plan.rb"
end
