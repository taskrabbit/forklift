require 'spec_helper'

describe 'elasticsearch' do  
  it "can read data (raw)"
  it "can read data (filtered)"

  it "can write new data"
  it "can update existing data"

  it "can delte a table"
  it "can drop a database"
  it "can read a list of tables"
  it "can truncate a table"
  it "can get the cols of a table"
  
  it "can lazy-create a table with primary keys provided"
  it "can lazy-create a table without primary keys provided"

  it "can corretly assign mysql data types from ruby"

  it "can do a raw data pipe"
  it "can do an incramental data pipe with only updated data"
  it "(optimistic_pipe) can determine if it should do an incramental or full pipe"

  it "can create a mysqldump"

  it "can run the mysql_optimistic_import pattern"
end