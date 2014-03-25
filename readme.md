# Forklift
Moving heavy databases around.

![picture](https://raw.github.com/taskrabbit/forklift/master/forklift.jpg)

## What?

[Forklift](https://github.com/taskrabbit/forklift) is a ruby gem that makes it easy for you to move your data around.  Forklift can be an integral part of your datawarehouse pipeline or a backup too.  Forklift can collect and collapse data from multiple sources or accross a source.  In forklift's first version, it was only a mySQL tool.  Now, you can create [transports]() to deal with the data of your choice.

## What does TaskRabbit use this for?

At TaskRabbit, the website you see at [www.taskrabbit.com](https://www.taskrabbit.com) is actually made up of many [smaller rails applications](http://en.wikipedia.org/wiki/Service-oriented_architecture).  When analyzing our site, we need to collect all of this data into one place so we can easily join across it.

We replicate all of our databases into one server in our office, and then use Forklift to extract the data we want into a common place.  This gives us the option to both look at live data and to have a more accessible transformed set which we create on a rolling basis. Our "Forklift Loop" also git-pulls to check for any new transformations before each run.

## Suggested Paterns

### In-Place Modificaiton

```ruby
source      = plan.connections[:mysql][:source]
destination = plan.connections[:mysql][:destination]

source.tables.each do |table|
  source.read(table, query) {|data| working.write(data, table) }
end

destination.exec!("./transformations.sql");
```

Pros: 

- faster
- requires less space for final storage

Cons: 

- leaves final databse in "incomplete" and "inconsistant" state for longer

### ETL (Extract -> Transform -> Load)

```ruby
source      = plan.connections[:mysql][:source]
working     = plan.connections[:mysql][:working]
destination = plan.connections[:mysql][:destination]

source.tables.each do |table|
  source.read(table, query) {|data| working.write(data, table) }
end

working.exec!("./transformations.sql");

working.tables.each do |table|
  working.optomistic_pipe(working.database, table, destination.database, table)
end
```

Pros: 

- auditable
- minimizes inconsistant state of fonal database

Cons: 

- slow
- requires 2x space of final working set

## Example Annotated Plan

Forklift expexts your project to be arranged like:

```bash
|-forklift.rb
|-/config
|--email.yml
|--/connections
|---/mysql
|----(DB).yml
|---/elasticsearch
|----(DB).yml
|-/log
|-/pid
|-/template
|-/transformations
|-/connections
|-Gemfile
|-Gemfile.lock
|-plan.rb
```

Run your plan with the forklift binary: `forklift plan.rb`

```ruby
# plan = Forklift::Plan.new
# Or, you can pass configs
plan = Forklift::Plan.new ({
  # :logger => {:debug => true}
})

plan.do! {
  # do! is a wrapper around common setup methods (pidfile locking, setting up the logger, etc)
  # you don't need to use do! if you want finer control

  # cleanup from a previous run
  destination = plan.connections[:mysql][:destination]
  destination.exec("./transformations/cleanup.sql");

  #  mySQL -> mySQL
  source = plan.connections[:mysql][:source]
  source.tables.each do |table|
    source.optomistic_pipe('source', table, 'destination', table)
    # will attempt to do an incramental pipe, will fall back to a full table copy
    # by default, incramental updates happen off of the `created_at` column, but you can modify this with "matcher"
  end

  # Elasticsearch -> mySQL
  source = plan.connections[:elasticsearch][:source]
  destination = plan.connections[:mysql][:destination]
  table = 'es_import'
  index = 'aaa'
  query = { :query => { :match_all => {} } } # pagination will happen automatically
  destination.truncate!(table) if destination.tables.include? table
  source.read(index, query) {|data| destination.write(data, table) }

  # mySQL -> Elasticsearch
  source = plan.connections[:mysql][:source]
  destination = plan.connections[:elasticsearch][:source]
  table = 'users'
  index = 'users'
  query = "select * from users" # pagination will happen automatically
  source.read(query) {|data| destination.write(data, table, true, 'user') }

  # ... and you can write your own connections [LINK GOES HERE]

  # Do some SQL stranformations
  # SQL transformations are done explicitly as they are writter
  destination = plan.connections[:mysql][:destination]
  destination.exec!("./transformations/combined_name.sql")

  # Do some Ruby transformations
  # Ruby transformations expect `do!(connection, forklift)` to be defined
  destination = plan.connections[:mysql][:destination]
  destination.exec!("./transformations/email_suffix.rb")

  # mySQL Dump the destination
  destination = plan.connections[:mysql][:destination]
  destination.dump('/tmp/destination.sql.gz')

  # email the logs and a summary
  destination = plan.connections[:mysql][:destination]

  email_args = {
    :to      => "YOU@FAKE.com",
    :from    => "Forklift",
    :subject => "Forklift has moved your database @ #{Time.new}",
  }

  email_varialbes = {
    :total_users_count => destination.read('select count(1) as "count" from users')[0][:count],
    :new_users_count => destination.read('select count(1) as "count" from users where date(created_at) = date(NOW())')[0][:count],
  }

  email_template = "./template/email.erb"
  plan.mailer.send_template(email_args, email_template, email_varialbes, plan.logger.messages) unless ENV['EMAIL'] == 'false'
}
```

## Workflow

```ruby
def do!
  self.logger.log "Starting forklift"
  # you can use `plan.logger.log` in your plan for logging
  self.pid.safe_to_run?
  self.pid.store!
  # use a pidfile to ensure that only one instance of forklift is running at a time; store the file if OK
  self.connect!
  # this will load all connections in /config/connections/#{type}/#{name}.yml into plan.connections {}
  # this will build all the connection objects (and try to connect in some cases)
  yield
  # your stuff here!
  self.logger.log "Completed forklift"
  self.pid.delete!
  # remove the pidfile
end

```

## Transports

Transports are how you interact with your data.  Every transport defines a `read` and `write` method which handle arrays of data object.  Transports optionaly define `pipe` methods which a shortcuts to copy data within a transport (IE: `insert into #{to_db}.#{to_table} select * from #{from_db}.#{from_table}` for mysql).   A trasport may also define other helers (like how to create a mysql dump).

A config file for each connection is to live in `./config/connections/#{transport}/` and will be loaded at boot.

### Creating your own transport

in the `/connections` firectory in your project, create a file that defines at least the following:

```ruby
module Forklift
  module Connection
    class Mixpanel < Forklift::Base::Connection

      def initialize(config, forklift)
        @config = config
        @forklift = forklift
      end

      def config
        @config
      end

      def forklift
        @forklift
      end

      def read(index, query, args)
        # ... 
        data = [] # data is an array of hashes
        # ...
        if block_given?
          yield data 
        else
          return data
        end
      end

      def write(data, table)
        # data is an array of hashes
        # "table" can be any argument(s) you need to know where/how to write
        # ... 
      end

      def pipe(from_table, from_db, to_table, to_db)
        # ...
      end

      private

      #/private

    end
  end
end
```

### mysql

**forklift methods**

- read(query, database=current_database, looping=true, limit=1000, offset=0)
- read_since(table, since, matcher=default_matcher, database=current_database)
  - a wrapper around `read` to get only rows since a timestamp
- write(data, table, to_update=false, database=current_database, primary_key='id', lazy=true, crash_on_extral_col=true)
  - `lazy` will create a table if not found
  = `crash_on_extral_col` will sanitize input to only contain the cols in the table
- pipe(from_table, from_db, to_table, to_db)
- incremental_pipe(from_table, from_db, to_table, to_db, matcher=default_matcher, primary_key='id')
  - `pipe` with only new data where time is greater than the latest `matcher` on the `to_db`
- optomistic_pipe(from_db, from_table, to_db, to_table, matcher=default_matcher, primary_key='id')
  - tries to `incremental_pipe`, falling back to `pipe`

**transport-specific methods**

- tables
  - list connection's database tables
- current_database
  - return the DB's name
- count(table, database=current_database)
  - count rows in table
- max_timestamp(table, matcher=default_matcher, database=current_database)
  - return the timestamp of the max(matcher) or 1970-01-01
- truncate!(table, database=current_database)
- columns(table, database=current_database)
- dump(file)
  - mysqldump the database to `file` via gzip

### elasticseatch

**forklift methods**

- read(index, query, looping=true, from=0, size=1000)
- write(data, index, update=false, type='forklift', primary_key=:id)

**transport-specific methods**

- delete_index(index)

## Transformations

Forklift allows you to create both Ruby transformations and script transformations

- It is up to the transport to define `exec_script`, and not all transports will support it.  Mysql can run `.sql` files, but there is not an equivielent for elasticsearch. 
- `.exec` runs and logs exceptions, while `.exec!` will raise on an error.  For example, `destination.exec("./transformations/cleanup.rb")` will run cleanup.rb on the destination database.
- Script files are run as-is, but ruby transformations must define a `do!` method in thier class and are passed `def do!(connection, forklift)`

```ruby
# Example transformation to count users
# count_users.rb

class CountUsers
  def do!(connection, forklift)
    forklift.logger.log "counting users"
    count = connection.count('users')
    forklift.logger.log "found #{count} users"
  end
end
```
## Emails

Forklift provides basic support for ERB-templated emails which can be sent at the end of every forklift run.  Want to notify folks automatically about how many new users we got yesterday?  Forklift can help you out.

```ruby
email_args = {
  :to      => "YOU@FAKE.com",
  :from    => "Forklift",
  :subject => "Forklift has moved your database @ #{Time.new}",
}

email_varialbes = {
  :total_users_count => destination.read('select count(1) as "count" from users')[0][:count],
  :new_users_count => destination.read('select count(1) as "count" from users where date(created_at) = date(NOW())')[0][:count],
}

email_template = "./template/email.erb"
plan.mailer.send_template(email_args, email_template, email_varialbes, plan.logger.messages)
```

## Options & Notes
- email_options is a hash consumed by the [Pony mail gem](https://github.com/benprew/pony)
- Forklift's logger is [Lumberjack](https://github.com/bdurand/lumberjack) with a wrapper to also echo the log lines to stdout and save them to an array to be accessed later by the email system.

- The mysql connections hash will be passed directly to a [mysql2](https://github.com/brianmario/mysql2) connection.
- The elasticsearch connections hash will be passed directly to a [elasticsearch](https://github.com/elasticsearch/elasticsearch-ruby) connection.
