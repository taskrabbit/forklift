require 'spec_helper'
require 'csv'

describe 'csv' do  

  after(:each) do
    SpecSeeds.setup_csv
  end

  it "can read data (simple)" do
    plan = SpecPlan.new
    @rows = []

    plan.do! {
      source = plan.connections[:csv][:forklift_test_source]
      source.read {|data| 
        @rows = (@rows + data)
      }
    }

    expect(@rows.length).to eql 5
    expect(@rows.first[:vendor_id]).to eql 1
    expect(@rows.last[:vendor_id]).to eql 5
  end

  it "can read partial data" do
    plan = SpecPlan.new
    @rows = []

    plan.do! {
      source = plan.connections[:csv][:forklift_test_source]
      @rows = source.read(3)
    }

    expect(@rows.length).to eql 3
    expect(@rows.first[:vendor_id]).to eql 1
    expect(@rows.last[:vendor_id]).to eql 3
  end

  it "can write data (simple)" do
    plan = SpecPlan.new
    data = [
      {thing: 1, when: Time.now},
      {thing: 2, when: Time.now},
    ]

    plan.do! {
      destination = plan.connections[:csv][:forklift_test_destination]
      destination.write(data)
    }

    @rows = SpecClient.csv('/tmp/destination.csv')
    expect(@rows.length).to eql 2
    expect(@rows.first[:thing]).to eql 1
    expect(@rows.last[:thing]).to eql 2
  end

  it "can append data" do
    plan = SpecPlan.new

    plan.do! {
      destination = plan.connections[:csv][:forklift_test_destination]

      data = [
        {thing: 1, when: Time.now},
        {thing: 2, when: Time.now},
      ]

      destination.write(data)

      data = [
        {thing: 3, when: Time.now},
      ]

      destination.write(data)
    }

    @rows = SpecClient.csv('/tmp/destination.csv')
    expect(@rows.length).to eql 3
    expect(@rows.first[:thing]).to eql 1
    expect(@rows.last[:thing]).to eql 3
  end

end