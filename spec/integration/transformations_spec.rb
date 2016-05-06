require 'spec_helper'

describe 'transformations' do

  before(:each) do
    SpecSeeds.setup_mysql
  end

  it "can run a native transformation" do
    plan = SpecPlan.new
    @rows = []

    raw = SpecClient.mysql('forklift_test_destination')

    plan.do! {
      source      = plan.connections[:mysql][:forklift_test_source_a]
      destination = plan.connections[:mysql][:forklift_test_destination]
      source.read('select * from `users`') {|data| destination.write(data, 'users') }

      expect( destination.columns("users").include?(:full_name) ).to eql false

      transformation_file = "#{File.dirname(__FILE__)}/../template/spec_user_transformation.sql"
      destination.exec!(transformation_file)

      expect( destination.columns("users").include?(:full_name) ).to eql true
    }
    plan.disconnect!
  end

  it "can run a ruby transformation" do
    plan = SpecPlan.new
    @rows = []

    raw = SpecClient.mysql('forklift_test_destination')

    plan.do! {
      source      = plan.connections[:mysql][:forklift_test_source_a]
      destination = plan.connections[:mysql][:forklift_test_destination]
      source.read('select * from `users`') {|data| destination.write(data, 'users') }

      expect( destination.columns("users").include?(:full_name) ).to eql false

      transformation_file = "#{File.dirname(__FILE__)}/../template/spec_user_transformation.rb"
      destination.exec!(transformation_file, {prefix: 'my_prefix' })

      expect( destination.columns("users").include?(:full_name) ).to eql true

      data = destination.read('select * from `users` where email="evan@example.com"')
      expect( data.first[:full_name] ).to eql 'my_prefix Evan T'
    }
    plan.disconnect!
  end

end
