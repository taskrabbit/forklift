require 'rubygems'

module Forklift

  lib = File.expand_path(File.dirname(__FILE__))
  
  require "#{lib}/base/utils.rb"
  require "#{lib}/base/pid.rb"
  require "#{lib}/base/logger.rb"
  require "#{lib}/base/mailer.rb"
  require "#{lib}/base/connection.rb"

  require "#{lib}/connection/mysql.rb"
  require "#{lib}/connection/elasticsearch.rb"

  require "#{lib}/plan.rb"
end
