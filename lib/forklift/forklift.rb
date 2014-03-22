require 'rubygems'

module Forklift

  lib = File.expand_path(File.dirname(__FILE__))
  
  require "#{lib}/base/utils.rb"
  require "#{lib}/base/pid.rb"
  require "#{lib}/base/logger.rb"
  require "#{lib}/base/mailer.rb"
  require "#{lib}/base/connection.rb"

  require "#{lib}/patterns.rb"

  Dir["#{lib}/transports/*.rb"].each {|file| require file }
  Dir["#{Dir.pwd}/transports/*.rb"].each {|file| require file } if File.directory?("#{Dir.pwd}/transports")

  require "#{lib}/plan.rb"
end
