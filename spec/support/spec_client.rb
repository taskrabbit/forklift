require 'yaml'
require 'erb'

class SpecClient

  def self.load_config(file)
    YAML.load(ERB.new(File.read(file)).result)
  end

  def self.mysql(name)
    file = File.join(File.dirname(__FILE__), '..', 'config', 'connections', 'mysql', "#{name}.yml")
    config = self.load_config(file)
    db = config[:database]
    config.delete(:database)
    connection = ::Mysql2::Client.new(config)
    begin
      connection.query("use `#{db}`")
    rescue Exception => e
      puts "#{e} => will create new databse #{db}"
    end
    connection
  end

  def self.pg(name)
    require 'pg' unless defined?(PG)
    file = File.join(File.dirname(__FILE__), '..', 'config', 'connections', 'pg', "#{name}.yml")
    config = self.load_config(file)
    db = config[:dbname]
    pg_conn = ::PG::Connection.new(config.merge(dbname: 'postgres'))
    pg_conn.exec(%{DROP DATABASE IF EXISTS #{db}})
    pg_conn.exec(%{CREATE DATABASE #{db}})
    pg_conn.close

    ::PG::Connection.new(config)
  end

  def self.elasticsearch(name)
    file = File.join(File.dirname(__FILE__), '..', 'config', 'connections', 'elasticsearch', "#{name}.yml")
    config = self.load_config(file)
    ::Elasticsearch::Client.new(config)
  end

  def self.csv(file)
    CSV.read(file, headers: true, converters: :all).map {|r| r = r.to_hash.symbolize_keys }
  end

end
