# Forklift
Moving heavy databases around.

![picture](https://raw.github.com/taskrabbit/forklift/master/forklift.jpg)

## What?

[Forklift](https://github.com/taskrabbit/forklift) is a ruby gem that makes it easy for you to move your data around.  Forklift can be an integral part of your datawarehouse pipeline or a backup too.  Forklift can collect and collapse data from multiple sources or accross a source.  In forklift's first version, it was only a MySQL tool.  Now, you can create [transports]() to deal with the data of your choice.

## What does TaskRabbit use this for?

At TaskRabbit, the website you see at [www.taskrabbit.com](https://www.taskrabbit.com) is actually made up of many [smaller rails applications](http://en.wikipedia.org/wiki/Service-oriented_architecture).  When analyzing our site, we need to collect all of this data into one place so we can easily join across it.

We replicate all of our databases into one server in our office, and then use Forklift to extract the data we want into a common place.  This gives us the option to both look at live data and to have a more accessible transformed set which we create on a rolling basis. Our "Forklift Loop" also git-pulls to check for any new transformations before each run.

## Suggested Patterns

### In-Place Modification

```ruby
source      = plan.connections[:mysql][:source]
destination = plan.connections[:mysql][:destination]

source.tables.each do |table|
  source.read(table, query) { |data| working.write(data, table) }
end

destination.exec!("./transformations.sql");
```

Pros:

- faster
- requires less space for final storage

Cons:

- leaves final databse in "incomplete" and "inconsistent" state for longer

### ETL (Extract -> Transform -> Load)

```ruby
source      = plan.connections[:mysql][:source]
working     = plan.connections[:mysql][:working]
destination = plan.connections[:mysql][:destination]

source.tables.each do |table|
  source.read(table, query) { |data| working.write(data, table) }
end

working.exec!("./transformations.sql")

working.tables.each do |table|
  working.optimistic_pipe(working.database, table, destination.database, table)
end
```

Pros:

- auditable
- minimizes inconsistent state of final database

Cons:

- slow
- requires 2x space of final working set

## Directory structure and set up

Forklift expects your project to be arranged like:

```bash
├── config/
|   ├── email.yml
├── connections/
|   ├── mysql/
|       ├── (DB).yml
|   ├── elasticsearch/
|       ├── (DB).yml
├── log/
├── pid/
├── template/
├── transformations/
├── Gemfile
├── Gemfile.lock
├── plan.rb
```

Make a new directory with a Gemfile like this:
```ruby
source 'http://rubygems.org'
gem 'forklift'
```

Then `bundle`

Use the generator by doing `bundle exec forklift --generate`

Make your plan using the examples below.

Run your plan `bundle exec forklift plan.rb`

## Example plans

### Simple extract and load (no transformations)

If you have multiple databases and want to consolidate into one, this plan
should suffice.

```ruby
plan = Forklift::Plan.new

plan.do! do
  # ==> Connections
  service1 = plan.connections[:mysql][:service1]
  service2 = plan.connections[:mysql][:service2]
  analytics_working = plan.connections[:mysql][:analytics_working]
  analytics = plan.connections[:mysql][:analytics]

  # ==> Extract
  # Load data from your services into your working database
  # If you want every table: service1.tables.each do |table|
  %w(users organizations).each do |table|
    service1.read("select * from `#{table}`") { |data| analytics_working.write(data, table) }
  end

  %w(orders line_items).each do |table|
    service2.read("select * from `#{table}`") { |data| analytics_working.write(data, table) }
  end

  # ==> Load
  # Load data from the working database to the final database
  analytics_working.tables.each do |table|
    # will attempt to do an incremental pipe, will fall back to a full table copy
    # by default, incremental updates happen off of the `updated_at` column, but you can modify this by setting the `matcher` argument
    # analytics_working.optimistic_pipe(analytics_working.current_database, table, analytics.current_database, table, 'another_timestamp_column')
    # If you want a full pipe instead of incremental, then just use `pipe` instead of `optimistic_pipe`
    analytics_working.optimistic_pipe(analytics_working.current_database, table, analytics.current_database, table)
  end
end
```

### ETL (Extract -> Transform -> Load)
TODO - improve this section with better examples
```ruby
# Do some SQL transformations
# SQL transformations are done exactly as they are written
destination = plan.connections[:mysql][:destination]
destination.exec!("./transformations/combined_name.sql")

# Do some Ruby transformations
# Ruby transformations expect `do!(connection, forklift)` to be defined
destination = plan.connections[:mysql][:destination]
destination.exec!("./transformations/email_suffix.rb")

# mySQL Dump the destination
destination = plan.connections[:mysql][:destination]
destination.dump('/tmp/destination.sql.gz')
```

### Elasticsearch to MySQL
```ruby
source = plan.connections[:elasticsearch][:source]
destination = plan.connections[:mysql][:destination]
table = 'es_import'
index = 'aaa'
query = { :query => { :match_all => {} } } # pagination will happen automatically
destination.truncate!(table) if destination.tables.include? table
source.read(index, query) {|data| destination.write(data, table) }
```

### MySQL to Elasticsearch
```ruby
source = plan.connections[:mysql][:source]
destination = plan.connections[:elasticsearch][:source]
table = 'users'
index = 'users'
query = "select * from users" # pagination will happen automatically
source.read(query) {|data| destination.write(data, table, true, 'user') }
```

### Email notifications when forklift finishes
Put this at the end of your plan but inside the `do!` block.
```ruby
# ==> Email
# Let your team know the outcome. Attaches the log.
email_args = {
  to: "team@yourcompany.com",
  from: "Forklift",
  subject: "Forklift has moved your database @ #{Time.new}",
  body: "So much data!"
}
plan.mailer.send(email_args, plan.logger.messages)
```

You can get fancy by using a template and erb:
```ruby
# ==> Email
# Let your team know the outcome. Attaches the log.
email_args = {
  to: "team@yourcompany.com",
  from: "Forklift",
  subject: "Forklift has moved your database @ #{Time.new}"
}
email_variables = {
  total_users_count: service1.read('select count(1) as "count" from users')[0][:count]
}
email_template = "./template/email.erb"
plan.mailer.send_template(email_args, email_template, email_variables, plan.logger.messages)
```

Then in `template/email.erb`:
```erb
<h1>Your forklift email</h1>

<ul>
  <li><strong>Total Users</strong>: <%= @total_users_count %></li>
</ul>
```

## Workflow

```ruby
# do! is a wrapper around common setup methods (pidfile locking, setting up the logger, etc)
# you don't need to use do! if you want finer control
def do!
  # you can use `plan.logger.log` in your plan for logging
  self.logger.log "Starting forklift"

  # use a pidfile to ensure that only one instance of forklift is running at a time; store the file if OK
  self.pid.safe_to_run?
  self.pid.store!

  # this will load all connections in /config/connections/#{type}/#{name}.yml into the plan.connections hash
  # and build all the connection objects (and try to connect in some cases)
  self.connect!

  yield # your stuff here!

  # remove the pidfile
  self.logger.log "Completed forklift"
  self.pid.delete!
end

```

## Transports

Transports are how you interact with your data.  Every transport defines `read` and `write` methods which handle arrays of data objects.  Transports optinally define a `pipe` method which is a shortcut to copy data within a transport (eg `insert into #{to_db}.#{to_table}; select * from #{from_db}.#{from_table}` for MySQL). A trasport may also define other helpers like how to create a MySQL dump).

Each transport should have a config file in `./config/connections/#{transport}/`. It will be loaded at boot.

### Creating your own transport

In the `/connections` directory in your project, create a file that defines at least the following:

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

### MySQL

#### Forklift methods

- read(query, database=current_database, looping=true, limit=1000, offset=0)
- read_since(table, since, matcher=default_matcher, database=current_database)
  - a wrapper around `read` to get only rows since a timestamp
- write(data, table, to_update=false, database=current_database, primary_key='id', lazy=true, crash_on_extral_col=true)
  - `lazy` will create a table if not found
  - `crash_on_extral_col` will sanitize input to only contain the cols in the table
- pipe(from_db, from_table, to_db, to_table)
- incremental_pipe(from_db, from_table, to_db, to_table, matcher=default_matcher, primary_key='id')
  - `pipe` with only new data where time is greater than the latest `matcher` on the `to_db`
- optimistic_pipe(from_db, from_table, to_db, to_table, matcher=default_matcher, primary_key='id')
  - tries to `incremental_pipe`, falling back to `pipe`

#### Transport-specific methods

- tables
  - list connection's database tables
- current_database
  - return the database's name
- count(table, database=current_database)
  - count rows in table
- max_timestamp(table, matcher=default_matcher, database=current_database)
  - return the timestamp of the max(matcher) or 1970-01-01
- truncate!(table, database=current_database)
- columns(table, database=current_database)
- dump(file)
  - mysqldump the database to `file` via gzip

### Elasticsearch

#### Forklift methods

- read(index, query, looping=true, from=0, size=1000)
- write(data, index, update=false, type='forklift', primary_key=:id)

#### Transport-specific methods

- delete_index(index)

## Transformations

Forklift allows you to create both Ruby transformations and script transformations.

- It is up to the transport to define `exec_script`, and not all transports will support it.  Mysql can run `.sql` files, but there is not an equivalent for elasticsearch.
- `.exec` runs and logs exceptions, while `.exec!` will raise on an error.  For example, `destination.exec("./transformations/cleanup.rb")` will run cleanup.rb on the destination database.
- Script files are run as-is, but ruby transformations must define a `do!` method in their class and are passed `def do!(connection, forklift)`

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

## Options & Notes
- Thanks to [@rahilsondhi](https://github.com/rahilsondhi) from [InternMatch](http://www.internmatch.com/) for all his help
- email_options is a hash consumed by the [Pony mail gem](https://github.com/benprew/pony)
- Forklift's logger is [Lumberjack](https://github.com/bdurand/lumberjack) with a wrapper to also echo the log lines to stdout and save them to an array to be accessed later by the email system.
- The mysql connections hash will be passed directly to a [mysql2](https://github.com/brianmario/mysql2) connection.
- The elasticsearch connections hash will be passed directly to a [elasticsearch](https://github.com/elasticsearch/elasticsearch-ruby) connection.
