require 'spec_helper'

describe Forklift::Connection::Mysql do

  describe "read/write utils" do
    before(:each) do
      SpecSeeds.setup_mysql
    end

    it "can read a list of tables" do
      plan = SpecPlan.new
      plan.do! {
        source = plan.connections[:mysql][:forklift_test_source_a]
        expect(source.tables).to include 'users'
        expect(source.tables).to include 'products'
        expect(source.tables).to include 'sales'
      }
    end

    it "can delte a table" do 
      plan = SpecPlan.new
      table = "users"
      plan.do! {
        source = plan.connections[:mysql][:forklift_test_source_a]
        expect(source.tables).to include 'users'
        source.drop! table
        expect(source.tables).to_not include 'users'
      }
    end

    it "can count the rows in a table" do
      plan = SpecPlan.new
      table = "users"
      plan.do! {
        source = plan.connections[:mysql][:forklift_test_source_a]
        expect(source.count(table)).to eql 5
      }
    end

    it "can truncate a table (both with and without !)" do 
      plan = SpecPlan.new
      table = "users"
      plan.do! {
        source = plan.connections[:mysql][:forklift_test_source_a]
        expect(source.count(table)).to eql 5
        source.truncate! table
        expect(source.count(table)).to eql 0
        expect { source.truncate(table) }.to_not raise_error
      }
    end

    it 'trunacte! will raise if the table does not exist' do
      plan = SpecPlan.new
      table = "other_table"
      plan.do! {
        source = plan.connections[:mysql][:forklift_test_source_a]
        expect { source.truncate!(table) }.to raise_error(/Table 'forklift_test_source_a.other_table' doesn't exist/)
      }
    end

    it "can get the columns of a table" do 
      plan = SpecPlan.new
      table = "sales"
      plan.do! {
        source = plan.connections[:mysql][:forklift_test_source_a]
        # ap source.columns(table)
        expect(source.columns(table)).to include 'id' 
        expect(source.columns(table)).to include 'user_id' 
        expect(source.columns(table)).to include 'product_id' 
        expect(source.columns(table)).to include 'timestamp' 
      }
    end

  end

  describe "#safe_values" do
    subject { described_class.new({}, {}) }

    it "escapes one trailing backslash" do
      values = ["foo\\"]
      subject.send(:safe_values, values).should == "\"foo\\\\\""
    end

    it "escapes two trailing backslashes" do
      values = ["foo\\\\"]
      subject.send(:safe_values, values).should == "\"foo\\\\\\\""
    end
  end
end