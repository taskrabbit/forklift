require 'spec_helper'

describe 'mysql' do  

  before(:each) do
    SpecSeeds.setup_mysql
  end

  it "can read data (raw)" do
    query = 'select * from `users`'
    plan = SpecPlan.new
    @rows = []
    plan.do! {
      source = plan.connections[:mysql][:forklift_test_source_a]
      source.read(query) {|data| 
        @rows = (@rows + data)
      }
    }

    expect(@rows.length).to eql 5
  end
  
  it "can read data (filtered)" do
    query = 'select * from `users`'
    plan = SpecPlan.new
    @rows = []
    plan.do! {
      source = plan.connections[:mysql][:forklift_test_source_a]
      source.read(query, source.current_database, false, 3, 0) {|data| 
        @rows = (@rows + data)
      }
    }

    expect(@rows.length).to eql 3
  end

  it "can write new data" do
    table = "users"
    data = [
      {:email => 'other@example.com', :first_name => 'other', :last_name => 'n', :created_at => Time.new.to_s(:sql), :updated_at => Time.new.to_s(:sql)}
    ]
    plan = SpecPlan.new
    plan.do! {
      destination = plan.connections[:mysql][:forklift_test_source_a]
      destination.write(data, table)
    }

    destination = SpecClient.mysql('forklift_test_source_a')
    count = destination.query('select count(1) as "count" from users').first['count']
    expect(count).to eql 6
  end

  it "can update existing data" do 
    table = "users"
    data = [
      {:id => 1, :email => 'evan@example.com', :first_name => 'New Name', :last_name => 'T', :created_at => Time.new.to_s(:sql), :updated_at => Time.new.to_s(:sql)}
    ]
    plan = SpecPlan.new
    plan.do! {
      destination = plan.connections[:mysql][:forklift_test_source_a]
      destination.write(data, table)
    }

    destination = SpecClient.mysql('forklift_test_source_a')
    count = destination.query('select count(1) as "count" from users').first['count']
    expect(count).to eql 5
    first_name = destination.query('select first_name from users where id = 1').first['first_name']
    expect(first_name).to eql 'New Name'
  end
  
  it "can lazy-create a table with primary keys provided"
  it "can lazy-create a table without primary keys provided"

  it "can corretly assign mysql data types from ruby"

  it "can create a mysqldump"
end