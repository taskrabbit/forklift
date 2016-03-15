require 'spec_helper'

describe 'elasticsearch' do  

  before(:each) do
    SpecSeeds.setup_elasticsearch
  end

  it "can read data (raw)" do
    index = 'forklift_test'
    query = { query: { match_all: {} } }
    plan = SpecPlan.new
    @rows = []
    plan.do! {
      source = plan.connections[:elasticsearch][:forklift_test]
      source.read(index, query) {|data| 
        @rows = (@rows + data)
      }
    }
    plan.disconnect!

    expect(@rows.length).to eql 5
  end

  it "can read data (filtered)" do
    index = 'forklift_test'
    query = { query: { match_all: {} } }
    plan = SpecPlan.new
    @rows = []
    plan.do! {
      source = plan.connections[:elasticsearch][:forklift_test]
      source.read(index, query, false, 0, 3) {|data|
        @rows = (@rows + data)
      }
    }
    plan.disconnect!

    expect(@rows.length).to eql 3
  end

  it "can write new data" do
    index = 'forklift_test'
    plan = SpecPlan.new
    data = [
      {id: 99, user_id: 99, product_id: 99, viewed_at: 99}
    ]
    plan.do! {
      destination = plan.connections[:elasticsearch][:forklift_test]
      destination.write(data, index)
    }
    plan.disconnect!

    destination = SpecClient.elasticsearch('forklift_test')
    count = destination.count({ index: index })["count"]

    expect(count).to eql 6
  end

  it "can overwrite existing data, probided a primary key" do
    index = 'forklift_test'
    plan = SpecPlan.new
    data = [
      {id: 1, user_id: 1, product_id: 1, viewed_at: 99}
    ]
    plan.do! {
      destination = plan.connections[:elasticsearch][:forklift_test]
      destination.write(data, index, true)
    }
    plan.disconnect!

    destination = SpecClient.elasticsearch('forklift_test')
    count = destination.count({ index: index })["count"]
    expect(count).to eql 5
    result = destination.search({ index: index, body: { query: {term: {id: 1}} } })
    expect(result["hits"]["total"]).to eql 1
    obj = result["hits"]["hits"][0]["_source"]
    expect(obj["id"]).to eql 1
    expect(obj["user_id"]).to eql 1
    expect(obj["product_id"]).to eql 1
    expect(obj["viewed_at"]).to eql 99
  end

  it "can delete an index" do
    index = 'other_test_index'
    plan = SpecPlan.new
    client = SpecClient.elasticsearch('forklift_test')
    data = [
      {id: 1}
    ]
    plan.do! {
      destination = plan.connections[:elasticsearch][:forklift_test]
      expect { client.search({ index: index }) }.to raise_error(/index_not_found_exception|IndexMissingException/)
      destination.write(data, index, true)
      expect { client.search({ index: index }) }.to_not raise_error
      destination.delete_index(index)
      expect { client.search({ index: index }) }.to raise_error(/index_not_found_exception|IndexMissingException/)
    }
    plan.disconnect!
  end
end
