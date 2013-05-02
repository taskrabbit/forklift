require 'rubygems'

module Forklift

  lib = File.expand_path(File.dirname(__FILE__))
  [
    'utils', 
    'debug', 
    'config', 
    'logger', 
    'connection', 
    'dump', 
    'check_evaluator', 
    'email', 
    'pid_file', 
    'plan', 
    'transformation',
    'before_after'
  ].each do |file|
    require "#{lib}/models/#{file}"
  end
end
