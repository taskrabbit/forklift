#############
## WARNING ##
#############

# THIS TEST SUITE IS VERY MEAN TO MYSQL AND ELASTICSEARCH
# IT *WILL* DELETE ANY CONTENT IN THE TEST DBs

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
APP_DIR ||= File.expand_path('../../', __FILE__)

require 'forklift/forklift'
require 'awesome_print'
require 'rspec'
require 'fileutils'

Dir["#{APP_DIR}/spec/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|

  config.before(:all) do
    piddir = "#{File.dirname(__FILE__)}/pid"
    FileUtils.rmdir(piddir) if File.exists?(piddir)
    SpecSeeds.setup_mysql
    SpecSeeds.setup_elasticsearch
  end

end
