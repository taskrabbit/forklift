require 'spec_helper'

describe 'basics' do  

  describe 'test suite setup' do  
    it 'seeded the mysql dbs' do
      client = SpecClient.mysql('forklift_test_source_a')
      tables = []
      client.query("show tables").each do |row|
        tables << row.values[0]
      end
      expect(tables.count).to eql 3
      client.close

      client = SpecClient.mysql('forklift_test_source_b')
      tables = []
      client.query("show tables").each do |row|
        tables << row.values[0]
      end
      expect(tables.count).to eql 1
      client.close
    end

    it 'seeded the elasticsearch db' do
      client = SpecClient.elasticsearch('forklift_test')
      results = client.search({ index: 'forklift_test' , body: { query: { match_all: {} } } })
      expect(results['hits']['total']).to eql 5
    end
  end

end