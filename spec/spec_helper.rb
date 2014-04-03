#############
## WARNING ##
#############

# THIS TEST SUITE IS VERY MEAN TO MYSQL AND ELASTICSEARCH
# IT *WILL* DELETE ANY CONTENT IN THE TEST DBs

ENV['RACK_ENV'] ||= 'test'
ENV['RAILS_ENV'] ||= 'test'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
APP_DIR ||= File.expand_path('../../', __FILE__)

require 'forklift/forklift'
require 'awesome_print'
require 'rspec'

Dir["#{APP_DIR}/spec/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|

  config.before(:all) do
    SpecSeeds.setup
  end

  # config.around(:each) do |example|
  #   IndexHelper.create_all
  #   example.run
  #   IndexHelper.delete_all
  # end

  # config.after(:each) do
  #   Timecop.return
  # end

end
