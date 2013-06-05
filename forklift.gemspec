# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'forklift/version'

Gem::Specification.new do |s|
  s.name        = "forklift"
  s.version     = Forklift::VERSION
  s.authors     = ["Evan Tahler"]
  s.email       = ["evan@taskrabbit.com"]
  s.homepage    = "https://github.com/taskrabbit/forklift"
  s.summary     = %q{Moving big databases around}
  s.description = %q{Moving big databases around}

  s.rubyforge_project = "forklift"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "activesupport"
  s.add_dependency "mysql2"
  s.add_dependency "pony"
  s.add_dependency "lumberjack"
  s.add_dependency "terminal-table"
  s.add_dependency "trollop"
end