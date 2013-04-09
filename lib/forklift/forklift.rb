require 'rubygems'

module Forklift
  lib = File.expand_path(File.dirname(__FILE__))
  [
    'config', 
    'logger', 
    'connection', 
    'dump', 
    'check_evaluator', 
    'email', 
    'parallel_query', 
    'pid_file', 
    'plan', 
    'transformation'
  ].each do |file|
    require "#{lib}/models/#{file}"
  end
end