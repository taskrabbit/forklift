# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'forklift/version'

Gem::Specification.new do |s|
  s.name        = "forklift_etl"
  s.version     = Forklift::VERSION
  s.authors     = ["Evan Tahler", "Ryan Garver"]
  s.email       = ["evan@taskrabbit.com", "ragarver@gmail.com"]
  s.homepage    = "https://github.com/taskrabbit/forklift"
  s.summary     = %q{Forklift: Moving big databases around. A ruby ETL tool.}
  s.description = %q{A collection of ETL tools and patterns for mysql and elasticsearch.}
  s.license     = "Apache-2.0"

  s.rubyforge_project = "forklift_etl"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "activesupport", '~> 4.0', ">= 4.0.0"
  s.add_dependency "mysql2",        '~> 0.0', ">= 0.0.1"
  s.add_dependency "elasticsearch", '~> 1.0', ">= 1.0.0"
  s.add_dependency "pony",          '~> 1.0', ">= 1.0.0"
  s.add_dependency "lumberjack",    '~> 1.0', ">= 1.0.0"
  s.add_dependency "pg",            '~> 1.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'email_spec'
end
