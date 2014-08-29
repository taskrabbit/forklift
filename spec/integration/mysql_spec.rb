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
      {email: 'other@example.com', first_name: 'other', last_name: 'n', created_at: Time.new.to_s(:db), updated_at: Time.new.to_s(:db)},
      {email: 'else@example.com',  first_name: 'else', last_name: 'n', created_at: Time.new.to_s(:db), updated_at: Time.new.to_s(:db)}
    ]
    plan = SpecPlan.new
    plan.do! {
      destination = plan.connections[:mysql][:forklift_test_source_a]
      destination.write(data, table)
    }

    destination = SpecClient.mysql('forklift_test_source_a')
    count = destination.query('select count(1) as "count" from users').first['count']
    expect(count).to eql 7
  end

  it "can update existing data" do 
    table = "users"
    data = [
      {id: 1, email: 'evan@example.com', first_name: 'New Name', last_name: 'T', created_at: Time.new.to_s(:db), updated_at: Time.new.to_s(:db)}
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

  describe 'lazy create' do

    after(:each) do
      destination = SpecClient.mysql('forklift_test_source_a')
      destination.query('drop table if exists `new_table`')
    end
    
    it "can lazy-create a table with primary keys provided" do 
      data = [
        {id: 1, thing: 'stuff a', updated_at: Time.new},
        {id: 2, thing: 'stuff b', updated_at: Time.new},
        {id: 3, thing: 'stuff c', updated_at: Time.new},
      ]
      table = "new_table"
      plan = SpecPlan.new
      plan.do! {
        destination = plan.connections[:mysql][:forklift_test_source_a]
        destination.write(data, table)
      }

      destination = SpecClient.mysql('forklift_test_source_a')
      cols = []
      destination.query("describe #{table}").each do |row|
        cols << row["Field"]
        case row["Field"]
        when "id" 
          expect(row["Type"]).to eql "bigint(20)"
        when "thing" 
          expect(row["Type"]).to eql "text"
        when "updated_at" 
          expect(row["Type"]).to eql "datetime"
        end
      end
      expect(cols).to eql ['id', 'thing', 'updated_at']
    end
    
    it "can lazy-create a table without primary keys provided" do
      data = [
        {thing: 'stuff a', number: 1.123, updated_at: Time.new},
        {thing: 'stuff b', number: 1.123, updated_at: Time.new},
        {thing: 'stuff c', number: 1.123, updated_at: Time.new},
      ]
      table = "new_table"
      plan = SpecPlan.new
      plan.do! {
        destination = plan.connections[:mysql][:forklift_test_source_a]
        destination.write(data, table)
      }

      destination = SpecClient.mysql('forklift_test_source_a')
      cols = []
      destination.query("describe #{table}").each do |row|
        cols << row["Field"]
        case row["Field"]
        when "id" 
          expect(row["Type"]).to eql "bigint(20)"
        when "thing" 
          expect(row["Type"]).to eql "text"
        when "number" 
          expect(row["Type"]).to eql "float"
        when "updated_at" 
          expect(row["Type"]).to eql "datetime"
        end
      end
      expect(cols).to eql ['id', 'thing', 'number', 'updated_at']
    end

    it "can add columns to exiting tables when new keys are provided" do
      table = "users"
      raw = SpecClient.mysql('forklift_test_source_a')

      count = raw.query("SHOW COLUMNS FROM #{table}").count
      expect(count).to eql 6

      data = [
        {email: 'other@example.com', something_else: :abc123, first_name: 'other', last_name: 'n', created_at: Time.new.to_s(:db), updated_at: Time.new.to_s(:db)}
      ]
      plan = SpecPlan.new
      plan.do! {
        destination = plan.connections[:mysql][:forklift_test_source_a]
        destination.write(data, table)
      }

      count = raw.query("SHOW COLUMNS FROM #{table}").count
      expect(count).to eql 7
    end

    it "can will seek further for null-ish values" do 
      data = [
        {id: 1, thing: 'stuff a', number: nil, updated_at: Time.new},
        {id: 2, thing: 'stuff b', number: nil, updated_at: Time.new},
        {id: 3, thing: 'stuff c', number: 100, updated_at: Time.new},
      ]
      table = "new_table"
      plan = SpecPlan.new
      plan.do! {
        destination = plan.connections[:mysql][:forklift_test_source_a]
        destination.write(data, table)
      }

      destination = SpecClient.mysql('forklift_test_source_a')
      cols = []
      destination.query("describe #{table}").each do |row|
        cols << row["Field"]
        case row["Field"]
        when "id" 
          expect(row["Type"]).to eql "bigint(20)"
        when "thing" 
          expect(row["Type"]).to eql "text"
        when "number" 
          expect(row["Type"]).to eql "bigint(20)"
        when "updated_at" 
          expect(row["Type"]).to eql "datetime"
        end
      end
      expect(cols).to eql ['id', 'thing', 'updated_at', 'number']
    end

    it "null rows will be text, and can be updated on subsequent writes" do 
      data = [
        {id: 1, number: nil, updated_at: Time.new},
        {id: 2, number: nil, updated_at: Time.new},
      ]
      
      table = "new_table"

      plan = SpecPlan.new
      plan.do! {
        destination = plan.connections[:mysql][:forklift_test_source_a]
        destination.write(data, table)
      }

      destination = SpecClient.mysql('forklift_test_source_a')
      cols = []

      destination.query("describe #{table}").each do |row|
        cols << row["Field"]
        case row["Field"]
        when "id" 
          expect(row["Type"]).to eql "bigint(20)"
        when "number" 
          expect(row["Type"]).to eql "varchar(0)"
        when "updated_at" 
          expect(row["Type"]).to eql "datetime"
        end
      end
      expect(cols).to eql ['id', 'updated_at', 'number']

      data = [
        {id: 3, number: 123, updated_at: Time.new},
      ]

      plan = SpecPlan.new
      plan.do! {
        destination = plan.connections[:mysql][:forklift_test_source_a]
        destination.write(data, table)
      }

      destination = SpecClient.mysql('forklift_test_source_a')
      cols = []

      destination.query("describe #{table}").each do |row|
        cols << row["Field"]
        case row["Field"]
        when "number" 
          expect(row["Type"]).to eql "bigint(20)"
        end
      end
      expect(cols).to eql ['id', 'updated_at', 'number']
    end

  end

end