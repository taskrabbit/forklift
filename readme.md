# Forklift
Moving heavy databases around.

![picture](https://raw.github.com/taskrabbit/forklift/master/forklift.jpg)

## What?

[Forklift](https://github.com/taskrabbit/forklift) is a ruby gem that can help you collect, augment, and save copies of your mySQL databases.  This is often called an ["ETL" tool](http://en.wikipedia.org/wiki/Extract,_transform,_load) as the steps in this process mirror the actions of "Extracting the data," "Transforming the data," and finally "Loading the data" into its final place.

With Forklift, you create a **Plan** which describes how to manipulate your data. The process for this involves (at least) three databases:

- Live Set
- Working Database
- Final Database

The "Live Set" is first loaded into the "Working Set" to create a copy of your production data we can manipulate without fear of breaking replication. Then, any transformations/manipulations are run on the data in the working set.  This might include normalizing or cleaning up data which was great for production but hard for analysts to use.  Finally, when all of your transformations are complete, that data is loaded into the final database.

Forklift is appropriate to use by itself or integrated within a larger project.  Forklift aims to be as fast as can be by using native mySQL copy commands and eschewing all ORMs and other RAM hogs.

## Features
- Can extract data from both local and remote databases
- Can perform integrity checks on your source data to determine if this run of Forklift should be executed
- Can run each Extract either each run or at a frequency
- Can run each Transform either each run or at a frequency
- Data kept in the woking database after each run to be used on subsequent transformations
- Only ETL'd tables will be copied into the final database, leaving other tables untouched
- Emails sent on errors

## What does TaskRabbit use this for?

At TaskRabbit, the website you see at [www.taskrabbit.com](https://www.taskrabbit.com) is actually made up of many [smaller rails applications](http://en.wikipedia.org/wiki/Service-oriented_architecture).  When analyzing our site, we need to collect all of this data into one place so we can easily join across it.

We replicate all of our databases into one server in our office, and then use Forklift to extract the data we want into a common place.  This gives us the option to both look at live data and to have a more accessible transformed set which we create on a rolling basis. Our "Forklift Loop" also git-pulls to check for any new transformations before each run.

## Example Annotated Plan

In Forklift, you build a plan.  You can add any action to the plan in any order before you run it.  You can have 0 or many actions of each type.  

```ruby
require 'rubygems'
require 'bundler'
Bundler.require(:default)
require 'forklift/forklift' # Be sure to have installed the gem!

#########
# SETUP #
#########

forklift = Forklift::Plan.new({
  
  :local_connection => {
    :host => "localhost",
    :username => "root",
    :password => nil,
  },
  
  :remote_connections => [
    {
      :name => "remote_connection_a",
      :host => "192.168.0.0",
      :username => "XXX",
      :password => "XXX",
    },
    {
      :name => "remote_connection_b",
      :host => "192.168.0.1",
      :username => "XXX",
      :password => "XXX",
    },
  ],

  :final_database => "FINAL",
  :working_database => "WORKING",

  :do_dump? => true,
  :dump_file => "/data/backups/dump-#{Time.new}.sql.gz",

  :do_email? => true,
  :email_logs_to => ['XXX'],
  :email_options => { 
    :via => :smtp, 
    :via_options => {
      :address              => 'smtp.gmail.com',
      :port                 => '587',
      :enable_starttls_auto => true,
      :user_name            => "XXX",
      :password             => "XXX",
      :authentication       => :plain,
    } 
  }

})

##########
# CHECKS #
##########

forklift.check_local_source({
  :name => 'CHECK_FOR_NEW_DATA',
  :database => 'test',
  :query => 'select (select max(created_at) from new_table) > (select date_sub(NOW(), interval 1 day))',
  :expected => '1'
})

forklift.check_remote_source({
  :connection_name => "remote_connection_b",
  :name => 'ANOTHER_CHECK',
  :database => 'stuff',
  :query => 'select count(1) from people',
  :expected => '100'
})

###########
# EXTRACT #
###########

forklift.import_local_database({
  :name => "import_database_1",
  :database => "database_1",
  :prefix => false,
  :frequency => 24 * 60 * 60,
})

forklift.import_local_database({
  :name => "import_database_2",
  :database => "database_2",
  :prefix => false,
  :only => ['table_1', 'table_2'],
})

forklift.import_remote_database({
  :name => "import_database_3",
  :connection_name => 'remote_connection_a',
  :database => "database_3",
  :prefix => true,
  :skip => ['schema_migrations']
})

#############
# TRANSFORM #
#############

transformation_base = File.dirname(__FILE__) + "/transformations"

forklift.transform_sql({
  :name => "transform_calendar",
  :file => "#{transformation_base}/calendars/create_calendars.sql",
  :frequency => 24 * 60 * 60,
})

forklift.transform_ruby({
  :name => "transform_ruby_test",
  :file => "#{transformation_base}/test/test.rb",
})

#######
# RUN #
#######

forklift.run

```

## Workflow

```ruby
def run
  lock_pidfile                # Ensure that only one instance of Forklift is running
  determine_what_to_run       # Should we run every part of the plan, or only some?
  rebuild_working_database    # Ensure that the working database exists
  ensure_forklift_data_table  # Ensure that the metadata table for forklift exists (used for frequency calculations)
  
  run_checks                  # Preform any data integrity checks
  run_before                  # Run any setup actions
  run_extractions             # Extact data from the life databases into the working database
  run_transformations         # Preform any Transformations
  run_load                    # Load the manipulated data into the final database
  run_after                   # Run any conclustion actions
  
  save_dump                   # mySQLdump the new final database for safe keeping
  send_emails                 # Email folks the status of this forklift and send any status emails
  unlock_pidfile              # Cleanup the pidfile so I can run next time
end
```

## Transformations

Forklift allows you to create both Ruby transformations and SQL transformations

### Ruby Transformations
- SQL Transformations are kept in a file ending in `.rb`
- Ruby Transformations should define a class which matches the name of the file (IE: class `MyTransformation` would be in a file called `my_transformation.rb`
- `logger.log(message)` is the best way to log but `logger.debug` is also available
- `database` is a string containing the name of the `working` database
- `connection` is an instance of `Forklift::Connection` and `connection.connection` is a raw mysql2 connection
- Classes need to define a `transform(connection, database, logger)` IE:

```ruby
class Test

  def transform(connection, database, logger)
    logger.log "Running on DB: #{database}"
    logger.log "Counting users..."
    connection.q("USE `#{database}`")
    users_count = connection.q("count(1) as 'users_count' from `users`")
    logger.log("There were #{users_count} users")
  end

end
```

### SQL Transformations
- SQL Transformations are kept in a file ending in `.sql`
- You can have many SQL statements per file
- SQL will be executed linearly as it is written in the file

SQL Transformations can be used to [generate new tables like this](http://stackoverflow.com/questions/1201874/calendar-table-for-data-warehouse) as well

## Befores & Afters

Forklift also alows you to run arbitraty "before" and "after" scripts to prepare or close-out your envrionemnt.  They can be SQL or Ruby (just like transformations).  For Ruby Befores & Afters, the database argument is the FINAL database, not the working database.  Use `def before()` or `def after()`

Before and After files are run each time, and cannot be restricted with a frequency

## Templated Emails

Forklift provides basic support for ERB-templated emails which can be sent at the end of every forklift run.  Want to notify folks automatically about how many new users we got yesterday?  Forklift can help you out.

## Defaults

The defaults for a new `Forklift::Plan` are:

```ruby
{
   :project_root => Dir.pwd,
   :lock_with_pid? => true,

   :final_database => {},
   :local_database => {},
   :forklift_data_table => '_forklift',
   
   :verbose? => true,

   :do_checks? => true,
   :do_extract? => true,
   :do_transform? => true,
   :do_load? => true,
   :do_email? => false,
   :do_dump? => false,
   :do_before? => true,
   :do_after? => true
 }
```

## Methods

### Test

```ruby
forklift.check_local_source({
  :name => STRING,     # A name for the test
  :database => STRING, # The Database to test
  :query => STRING,    # The Query to Run.  Needs to return only 1 row with 1 value
  :expected => STRING  # The response to compare against
})

forklift.check_remote_source({
  :name => STRING,             # A name for the test
  :connection_name => STRING,  # The name of the remote_connection
  :database => STRING,         # The Database to test
  :query => STRING,            # The Query to Run.  Needs to return only 1 row with 1 value
  :expected => STRING          # The response to compare against
})
```

### Extract

```ruby
forklift.import_local_database({
  :name => STRING,                  # A name for the action
  :database => STRING,              # The Database to Extract
  :prefix => BOOLEAN,               # Should we prefix the names of all tables in this database when imported wight the database?
  :frequency => INTEGER (seconds),  # How often should we import this database?
  :skip => ARRAY OR STRINGS          # A list of tables to ignore and not import
  :only => ARRAY OR STRINGS          # A list of tables to ignore and not import (use :only or :skip, not both)
})

forklift.import_remote_database({
  :name => STRING,                  # A name for the action
  :connection_name => STRING,       # The name of the remote_connection
  :database => STRING,              # The Database to Extract
  :prefix => BOOLEAN,               # Should we prefix the names of all tables in this database when imported wight the database?
  :frequency => INTEGER (seconds),  # How often should we import this database?
  :skip => ARRAY OR STRINGS          # A list of tables to ignore and not import
  :only => ARRAY OR STRINGS          # A list of tables to ignore and not import (use :only or :skip, not both)
})
```

### Transform

```ruby
forklift.transform_sql({
  :name => STRING,                 # A name for the action
  :file => STRING,                 # The transformation file to run
  :frequency => INTEGER (seconds), # How often should we run this transformation?
})

forklift.transform_ruby({
  :name => STRING,                 # A name for the action
  :file => STRING,                 # The transformation file to run
  :frequency => INTEGER (seconds), # How often should we run this transformation?
})

forklift.transform_directory({
  :name => STRING,                 # A name for the action
  :frequency => INTEGER (seconds), # How often should we run this transformation?
  :directory => STRING             # A directory of files to run (ruby/sql)
})
```

### Before & After

```ruby
forklift.before_sql({
  :name => STRING,                 # A name for the action
  :file => STRING,                 # The before file to run
})

forklift.before_ruby({
  :name => STRING,                 # A name for the action
  :file => STRING,                 # The before file to run
})

forklift.after_sql({
  :name => STRING,                 # A name for the action
  :file => STRING,                 # The after file to run
})

forklift.after_ruby({
  :name => STRING,                 # A name for the action
  :file => STRING,                 # The after file to run
})

forklift.before_directory({
  :name => STRING,                 # A name for the action
  :directory => STRING             # A directory of files to run (ruby/sql)
})

forklift.after_directory({
  :name => STRING,                 # A name for the action
  :directory => STRING             # A directory of files to run (ruby/sql)
})

```

### Templated Emails

```ruby
forklift.templated_email({
  :to => STRING,        # The recipient of the email
  :subject => STRING,   # The subject of the email
  :template => STRING,  # The path to the ERB template file
  :variables => {       # Symbolized hash
    :KEY => VALUE,      # > if VALUE is a string which contains "select", the SQL statement will be evaluated on the final DB
    :KEY => VALUE,      # > otherwise, the litteral value will be passed to the template as a string
  }
})
```

## Command Line Options

### Help

Forklift's help: `ruby #{your_plan}.rb --help`

```bash
Options:
      --debug, -d:   Use debug mode
  --names, -n <s>:   specific set of named actions to run
     --checks, -c:   (overide) use checks
    --extract, -e:   (overide) use extract
  --transform, -t:   (overide) use transform
       --load, -l:   (overide) use load
      --email, -m:   (overide) use email
       --dump, -u:   (overide) use dump
     --before, -b:   (overide) use before
      --after, -a:   (overide) use after
       --help, -h:   Show this message
```

By default, forklift will run sections defined in your plan.  However, there might be times which you need to only run part of your plan.  To help you with this, there are 2 paterns which allow for command line use:

### Step Definition

You can pass the steps which you specificly wish to run to forklift, which will overwrite your `do_*` blocks in your plan.  For example: 

- `ruby #{your_plan}.rb --no-checks` will run your plan as normal, but skip the cheks.  
- `ruby #{your_plan}.rb --no-checks --no-extrat --no-transform --no-load --no-dump --no-before --no-after` would only send emails

### Named actions

Alternatively, if you only want to run a specific action from you plan, you can use the `names` option.  You will note above that each step you define in your plan has a `:name` attribute.  This is used to signal forklift to run only that step.  For example:

- `ruby #{your_plan}.rb --names="send_daily_email"` would only re-send the email.  It will run against the existing forklift database.
- `ruby #{your_plan}.rb --names="send_daily_email, DUMP"` would only re-send the email and dump the `final` database.  The email will run against the existing forklift database.

`LOAD` and `DUMP` are the only reserved names to indicate those specific steps should be run by name.

### Debug Mode

You can launch forklift in "debug mode" with `--debug` (we check `ARGV["--debug"]` and `ARGV["-debug"]`).  In debug mode the following will happen:
- verbose = true
- no SQL will be run (extract, load)
- no transforms will be run
- no email will be sent
- no mySQL dumps will be created

## Options & Notes
- email_options is a hash consumed by the [Pony mail gem](https://github.com/benprew/pony)
- Forklift's logger is [Lumberjack](https://github.com/bdurand/lumberjack) with a wrapper to also echo the log lines to stdout and save them to an array to be accessed later by the email system.
- The connections hash will be passed directly to a [mysql2](https://github.com/brianmario/mysql2) connection.  Follow the link to see all the available options.

## Limitations
- mySQL only (the [mysql2](https://github.com/brianmario/mysql2) gem specifically)