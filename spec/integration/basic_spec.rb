require 'spec_helper'

describe 'basics' do  

  it 'seeded the dbs' do
    client = SpecClient.mysql('forklift_test_source_a')
    tables = []
    client.query("show tables").each do |row|
      tables << row.values[0]
    end
    expect(tables.count).to eql 3
  end

end