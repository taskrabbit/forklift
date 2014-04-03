require 'json'

class SpecSeeds

  def self.setup_mysql
    mysql_connections         = []
    mysql_databases           = []

    files = Dir["#{File.dirname(__FILE__)}/../config/connections/mysql/*.yml"]
    files.each do |f|
      name = f.split('/').last.gsub('.yml','')
      mysql_connections << ::SpecClient.mysql(name)
      mysql_databases << name
    end

    i = 0
    while i < mysql_connections.count
      conn = mysql_connections[i]
      db   = mysql_databases[i]
      seed = File.join(File.dirname(__FILE__), '..', 'support', 'dumps', 'mysql', "#{db}.sql")
      conn.query("drop database if exists `#{db}`")
      conn.query("create database `#{db}`")
      conn.query("use `#{db}`")
      if File.exists? seed
        lines = File.read(seed).split(";")
        lines.each do |line|
          conn.query(line) if line[0] != "#"
        end
      end

      i = i + 1
    end
  end

  def self.setup_elasticsearch
    elasticsearch_connections = []
    elasticsearch_databases   = []

    files = Dir["#{File.dirname(__FILE__)}/../config/connections/elasticsearch/*.yml"]
    files.each do |f|
      name = f.split('/').last.gsub('.yml','')
      elasticsearch_connections << ::SpecClient.elasticsearch(name)
      elasticsearch_databases << name
    end

    i = 0
    while i < elasticsearch_connections.count
      conn  = elasticsearch_connections[i]
      index = elasticsearch_databases[i]
      seed  = File.join(File.dirname(__FILE__), '..', 'support', 'dumps', 'elasticsearch', "#{index}.json")
      conn.indices.delete({ :index => index }) if conn.indices.exists({ :index => index })
      if File.exists? seed
        lines = JSON.parse(File.read(seed))
        lines.each do |line|
          object = {
            :index => index,
            :body  => line,
            :type  => 'seed',
            :id    => line[:id]
          }
          conn.index object # assumes ES is setup to allow index creation on write
        end
        conn.indices.refresh({ :index => index })
      end
      i = i + 1
    end
  end

end