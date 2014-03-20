require 'rubygems'
require 'bundler'
Bundler.require(:default)

require 'forklift/forklift'

# plan = Forklift::Plan.new
# Or, you can pass configs
plan = Forklift::Plan.new ({:logger => {:debug => true}})

plan.do! {
  # do! is a wrapper around common setup methods
  # you don't need to use do! if you want finer control

  # cleanup from a previous run
  destination = plan.connections[:mysql][:destination]
  destination.drop! 'users' if destination.tables.include? 'users'

  #  mySQL -> mySQL
  source = plan.connections[:mysql][:source]
  source.tables.each do |table|
    source.optomistic_pipe('source', table, 'destination', table)
    # will attempt to do an incramental pipe, will fall back to a full table copy
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
  destination = plan.connections[:mysql][:destination]
  destination.exec("./transformations/combined_name.sql")

  # Do some Ruby transformations
  destination = plan.connections[:mysql][:destination]
  destination.exec("./transformations/email_suffix.rb")

}

# email the logs and a summary
destination = plan.connections[:mysql][:destination]
email_args = {
  :to      => "evan@taskrabbit.com",
  :from    => "Forklift",
  :subject => "Forklift has moved your database @ #{Time.new}",
}
email_varialbes = {
  :total_users_count => destination.read('select count(1) as "count" from users')[0][:count],
  :new_users_count => destination.read('select count(1) as "count" from users where date(created_at) = date(NOW())')[0][:count],
}
email_template = "./template/email.erb"
plan.mailer.send_template(email_args, email_template, email_varialbes, plan.logger.messages) unless ENV['EMAIL'] == 'false'
