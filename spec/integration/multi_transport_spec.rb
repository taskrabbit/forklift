require 'spec_helper'

describe 'multiple trasport types' do

  before(:each) do
    SpecSeeds.setup_mysql
    SpecSeeds.setup_elasticsearch
  end

  describe 'elasticsearch => mysql' do  
    it 'can load in a full query' do
      table = 'es_import'
      index = 'forklift_test'
      query = { :query => { :match_all => {} } }
      plan = SpecPlan.new
      plan.do! {
        source = plan.connections[:elasticsearch][:forklift_test]
        destination = plan.connections[:mysql][:forklift_test_destination]
        source.read(index, query) {|data| destination.write(data, table) }
      }

      destination = SpecClient.mysql('forklift_test_destination')
      rows = destination.query("select count(1) as 'count' from es_import").first["count"]
      expect(rows).to eql 5
    end

    it 'can load in a partial query' do
      table = 'es_import'
      index = 'forklift_test'
      query = { :query => { :match_all => {} }, :sort => [{ :id => {:order => "asc" } }] }
      plan = SpecPlan.new
      plan.do! {
        source = plan.connections[:elasticsearch][:forklift_test]
        destination = plan.connections[:mysql][:forklift_test_destination]
        source.read(index, query, false, 0, 3) {|data| destination.write(data, table) }
      }

      destination = SpecClient.mysql('forklift_test_destination')
      rows = destination.query("select count(1) as 'count' from es_import").first["count"]
      expect(rows).to eql 3
      min = destination.query("select min(id) as 'min' from es_import").first["min"]
      expect(min).to eql 1
      max = destination.query("select max(id) as 'max' from es_import").first["max"]
      expect(max).to eql 3
    end

    it 'can detect data types' do
      table = 'es_import'
      index = 'forklift_test'
      query = { :query => { :match_all => {} } }
      plan = SpecPlan.new
      plan.do! {
        source = plan.connections[:elasticsearch][:forklift_test]
        destination = plan.connections[:mysql][:forklift_test_destination]
        source.read(index, query) {|data| 
          clean_data = []
          data.each do |row|
            row[:viewed_at] = Time.at(row[:viewed_at])
            clean_data << row
          end
          destination.write(clean_data, table) 
        }
      }

      destination = SpecClient.mysql('forklift_test_destination')
      max = destination.query("select max(viewed_at) as 'max' from es_import").first["max"]
      expect(max.class).to eql Time
    end

  end

  describe 'mysql => elasticsearch' do  

    after(:each) do
      es = SpecClient.elasticsearch('forklift_test')
      es.indices.delete({ :index => 'users' }) if es.indices.exists({ :index => 'users' })
    end

    it 'can load in a full table' do
      table = 'users'
      index = 'users'
      plan = SpecPlan.new
      plan.do! {
        source = plan.connections[:mysql][:forklift_test_source_a]
        destination = plan.connections[:elasticsearch][:forklift_test]
        source.read("select * from #{table}") {|data| destination.write(data, index) }
      }

      destination = SpecClient.elasticsearch('forklift_test')
      count = destination.count({ :index => index })["count"]
      expect(count).to eql 5
    end
    
    it 'can load in only some rows' do
      table = 'users'
      index = 'users'
      plan = SpecPlan.new
      plan.do! {
        source = plan.connections[:mysql][:forklift_test_source_a]
        destination = plan.connections[:elasticsearch][:forklift_test]
        source.read("select * from #{table}", source.current_database, false, 3, 0) {|data| 
          destination.write(data, index) 
        }
      }

      destination = SpecClient.elasticsearch('forklift_test')
      count = destination.count({ :index => index })["count"]
      expect(count).to eql 3
    end
  end

end