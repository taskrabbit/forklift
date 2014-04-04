require 'spec_helper'

describe 'mysql patterns' do  

  before(:each) do
    SpecSeeds.setup_mysql
  end

  it "can do a raw data pipe" do
    plan = SpecPlan.new
    plan.do! {
      source = plan.connections[:mysql][:forklift_test_source_a]
      destination = plan.connections[:mysql][:forklift_test_destination]
      
      expect(source.tables.length).to eql 3
      expect(destination.tables.length).to eql 0
      
      source.tables.each do |table|
        Forklift::Patterns::Mysql.pipe(source, table, destination, table)
      end

      expect(destination.tables.length).to eql 3
    }
  end

  it "can do an incramental data pipe with only updated data" do
    plan = SpecPlan.new
    table = 'users'
    plan.do! {
      source = plan.connections[:mysql][:forklift_test_source_a]
      destination = plan.connections[:mysql][:forklift_test_destination]
      Forklift::Patterns::Mysql.incremental_pipe(source, table, destination, table)

      expect(destination.count('users')).to eql 5
      expect(destination.read('select first_name from users where id = 1')[0][:first_name]).to eql 'Evan'

      source.q("UPDATE `users` SET `first_name` = 'EvanAgain' WHERE `id` = '1'")
      source.q("UPDATE `users` SET `updated_at` = NOW() WHERE `id` = '1'")

      Forklift::Patterns::Mysql.incremental_pipe(source, table, destination, table)

      expect(destination.count('users')).to eql 5
      expect(destination.read('select first_name from users where id = 1')[0][:first_name]).to eql 'EvanAgain'
    }
  end

  it "(optimistic_pipe) can determine if it should do an incramental or full pipe" do
    plan = SpecPlan.new
    plan.do! {
      source = plan.connections[:mysql][:forklift_test_source_a]
      expect(Forklift::Patterns::Mysql.can_incremental_pipe?(source, 'users')).to eql true
      expect(Forklift::Patterns::Mysql.can_incremental_pipe?(source, 'sales')).to eql false
      expect(Forklift::Patterns::Mysql.can_incremental_pipe?(source, 'products')).to eql true
    }
  end

  it "can run the mysql_optimistic_import pattern" do
    plan = SpecPlan.new
    plan.do! {
      source = plan.connections[:mysql][:forklift_test_source_a]
      destination = plan.connections[:mysql][:forklift_test_destination]

      Forklift::Patterns::Mysql.mysql_optimistic_import(source, destination)

      expect(destination.tables.length).to eql 3

      source.q("UPDATE `users` SET `first_name` = 'EvanAgain' WHERE `id` = '1'")
      source.q("UPDATE `users` SET `updated_at` = NOW() WHERE `id` = '1'")

      Forklift::Patterns::Mysql.mysql_optimistic_import(source, destination)

      expect(destination.count('users')).to eql 5
      expect(destination.read('select first_name from users where id = 1')[0][:first_name]).to eql 'EvanAgain'
    }
  end
end