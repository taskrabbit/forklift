# Forklift ETL

---

## THIS TOOL IS NO LONGER SUPORTED.
It has been succeded by [Empujar](https://github.com/taskrabbit/empujar)

---

Moving heavy databases around. [![Gem Version](https://badge.fury.io/rb/forklift_etl.svg)](http://badge.fury.io/rb/forklift_etl)
[![Build Status](https://secure.travis-ci.org/taskrabbit/forklift.png?branch=master)](http://travis-ci.org/taskrabbit/forklift)

![picture](https://raw.github.com/taskrabbit/forklift/master/forklift.jpg)

## What?

[Forklift](https://github.com/taskrabbit/forklift) is a ruby gem that makes it easy for you to move your data around.  Forklift can be an integral part of your datawarehouse pipeline or a backup tool.  Forklift can collect and collapse data from multiple sources or across a single source.  In forklift's first version, it was only a MySQL tool but now, you can create transports to deal with the data of your choice.

## Set up

Make a new directory with a `Gemfile` like this:
```ruby
source 'http://rubygems.org'
gem 'forklift_etl'
```

Then `bundle`

Use the generator by doing `(bundle exec) forklift --generate`

Make your `plan.rb` using the examples below.

Run your plan `forklift plan.rb`
You can run specific parts of your plan like `forklift plan.rb step1 step5`

### Directory structure
Forklift expects your project to be arranged like:

```bash
├── config/
|   ├── email.yml
├── connections/
|   ├── mysql/
|       ├── (DB).yml
|   ├── elasticsearch/
|       ├── (DB).yml
|   ├── csv/
|       ├── (file).yml
├── log/
├── pid/
├── template/
├── patterns/
├── transformations/
├── Gemfile
├── Gemfile.lock
├── plan.rb
```

To enable a foklift connection, all you need to do is place the yml config file for it within `/config/connections/(type)/(name).yml`
Files you place within `/patterns/` or `connections/(type)/` will be loaded automatically.

## Examples 

### Example Project

Visit the [`/example`](https://github.com/taskrabbit/forklift/tree/master/example) directory to see a whole forklift project.

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
  # Data will be extracted in 1000 row collections
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
    # If you want a full pipe instead of incremental, then just use `pipe` instead of `optimistic_pipe`
    # The `pipe pattern` works within the same database.  To copy across databases, try the `mysql_optimistic_import` method
    Forklift::Patterns::Mysql.optimistic_pipe(analytics_working.current_database, table, analytics.current_database, table)
  end
end
```

### Simple mySQL ETL
```ruby
plan = Forklift::Plan.new
plan.do! do
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
end
```

### Elasticsearch to MySQL
```ruby
plan = Forklift::Plan.new
plan.do! do
  source = plan.connections[:elasticsearch][:source]
  destination = plan.connections[:mysql][:destination]
  table = 'es_import'
  index = 'aaa'
  query = { query: { match_all: {} } } # pagination will happen automatically
  destination.truncate!(table) if destination.tables.include? table
  source.read(index, query) {|data| destination.write(data, table) }
end
```

### MySQL to Elasticsearch
```ruby
plan = Forklift::Plan.new
plan.do! do
  source = plan.connections[:mysql][:source]
  destination = plan.connections[:elasticsearch][:source]
  table = 'users'
  index = 'users'
  query = "select * from users" # pagination will happen automatically
  source.read(query) {|data| destination.write(data, table, true, 'user') }
end
```

## Forklift Emails

#### Setup
Put this at the end of your plan inside the `do!` block.
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

#### ERB templates
You can get fancy by using an ERB template for your email and SQL variables:
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

#### Config
When you run `forklift --generate`, we create `config/email.yml` for you:

```yml
# Configuration is passed to Pony (https://github.com/benprew/pony)

# ==> SMTP
# If testing locally, mailcatcher (https://github.com/sj26/mailcatcher) is a helpful gem
via: smtp
via_options:
  address: localhost
  port: 1025
  # user_name: user
  # password: password
  # authentication: :plain # :plain, :login, :cram_md5, no auth by default
  # domain: "localhost.localdomain" # the HELO domain provided by the client to the server

# ==> Sendmail
# via: sendmail
# via_options:
#   location: /usr/sbin/sendmail
#   arguments: '-t -i'
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

### Steps

You can optionally divide up your forklift plan into steps:
```ruby
plan = Forklift::Plan.new
plan.do! do

  plan.step('Mysql Import'){
    source = plan.connections[:mysql][:source]
    destination = plan.connections[:mysql][:destination]
    source.tables.each do |table|
      Forklift::Patterns::Mysql.optimistic_pipe(source, table, destination, table)
    end
  }

  plan.step('Elasticsearch Import'){
    source = plan.connections[:elasticsearch][:source]
    destination = plan.connections[:mysql][:destination]
    table = 'es_import'
    index = 'aaa'
    query = { query: { match_all: {} } } # pagination will happen automatically
    destination.truncate!(table) if destination.tables.include? table
    source.read(index, query) {|data| destination.write(data, table) }
  }

end  
```

When you use steps, you can run your whole plan, or just part if it with command line arguments.  For example, `forklift plan.rb "Elasticsearch Import"` would just run that single portion of the plan.  Note that any parts of your plan not within a step will be run each time. 

### Error Handling

By default, exceptions within your plan will raise and crash your application.  However, you can pass an optional `error_handler` lambda to your step about how to handle the error.  the `error_handler` will be passed (`step_name`,`exception`).  If you don't re-raise within your error handler, your plan will continue to excecute.  For example:

```ruby

error_handler = lambda { |name, exception|
  if exception.class =~ /connection/
    # I can't connect, I should halt
    raise e
  elsif exception.class =~ /SoftError/
    # this type of error is OK
  else
    raise e
  end
}

plan.step('a_complex_step', error_handler){
  # ...
}

```

## Transports

Transports are how you interact with your data.  Every transport defines `read` and `write` methods which handle arrays of data objects (and the helper methods required).  

Each transport should have a config file in `./config/connections/#{transport}/`. It will be loaded at boot.

Transports optionally define helper methods which are a shortcut to copy data *within* a transport, like the mysql `pipe` methods (i.e.: `insert into #{to_db}.#{to_table}; select * from #{from_db}.#{from_table})`. A transport may also define other helpers (like how to create a MySQL dump).  These should be defined in `/patterns/#{type}.rb` within the `Forklift::Patterns::#{type}` namespace.

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
- columns(table, database=current_database, return_types=false)
- rename(table, new_table, database, new_database)
- dump(file)
  - mysqldump the database to `file` via gzip

#### Patterns

- pipe(from_db, from_table, to_db, to_table)
- incremental_pipe(from_db, from_table, to_db, to_table, matcher=default_matcher, primary_key='id')
  - `pipe` with only new data where time is greater than the latest `matcher` on the `to_db`
- optimistic_pipe(from_db, from_table, to_db, to_table, matcher=default_matcher, primary_key='id')
  - tries to `incremental_pipe`, falling back to `pipe`
- mysql_optimistic_import(source, destination)
  - tries to do an incramental table copy, falls back to a full table copy
  - this differs from `pipe`, as all data is loaded into forklift, rather than relying on mysql transfer methods
- write_high_water_mark(db, time, matcher)
  - The high water method will stub a row in all tables with a `default_matcher` column prentending to have a record from `time`

### Elasticsearch

#### Forklift methods

- read(index, query, looping=true, from=0, size=1000)
- write(data, index, update=false, type='forklift', primary_key=:id)

#### Transport-specific methods

- delete_index(index)

### Csv

#### Forklift methods

- read(size)
- write(data, append=true)

## Transformations

Forklift allows you to create both Ruby transformations and script transformations.

- It is up to the transport to define `exec_script`, and not all transports will support it.  Mysql can run `.sql` files, but there is not an equivalent for elasticsearch. Mysql scripts evaluate statement by statement. The delimeter (by default `;`) can be redefined using the `delimeter` command as described [here](http://dev.mysql.com/doc/refman/5.7/en/stored-programs-defining.html)
- `.exec` runs and logs exceptions, while `.exec!` will raise on an error.  For example, `destination.exec("./transformations/cleanup.rb")` will run cleanup.rb on the destination database.
- Script files are run as-is, but ruby transformations must define a `do!` method in their class and are passed `def do!(connection, forklift)`
- args is optional, and can be passed in from your plan

```ruby
# Example transformation to count users
# count_users.rb

class CountUsers
  def do!(connection, forklift, args)
    forklift.logger.log "counting users"
    count = connection.count('users')
    forklift.logger.log "[#{args.name}] found #{count} users"
  end
end
```

```ruby
# in your plan.rb
plan = Forklift::Plan.new
plan.do! do
  destination = plan.connections[:mysql][:destination]
  destination.exec!("./transformations/combined_name.sql", {name: 'user counter'})

  end
```

## Options & Notes
- Thanks to [@rahilsondhi](https://github.com/rahilsondhi), [@rgarver](https://github.com/rgarver) and [Looksharp](https://www.looksharp.com/) for all their help
- email_options is a hash consumed by the [Pony mail gem](https://github.com/benprew/pony)
- Forklift's logger is [Lumberjack](https://github.com/bdurand/lumberjack) with a wrapper to also echo the log lines to stdout and save them to an array to be accessed later by the email system.
- The mysql connections hash will be passed directly to a [mysql2](https://github.com/brianmario/mysql2) connection.
- The elasticsearch connections hash will be passed directly to a [elasticsearch](https://github.com/elasticsearch/elasticsearch-ruby) connection.
- Your databases must exist. Forklift will not create them for you.
- Ensure your databases have the right encoding (eg utf8) or you will get errors like `#<Mysql2::Error: Incorrect string value: '\xEF\xBF\xBDFal...' for column 'YOURCOLUMN’ at row 1>`
- If testing locally, mailcatcher (https://github.com/sj26/mailcatcher) is a helpful gem to test your email sending

## Contributing and Testing
To run this test suite, you will need access to both a mysql and elasticsearch database. Test configurations are saved in `/spec/config/connections`.
