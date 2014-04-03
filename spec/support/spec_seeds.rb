class SpecSeeds

  def self.setup
    mysql_connections         = []
    elasticsearch_connections = []
    mysql_databases           = []
    elasticsearch_databases   = []

    files = Dir["#{File.dirname(__FILE__)}/../config/connections/mysql/*.yml"]
    files.each do |f|
      name = f.split('/').last.gsub('.yml','')
      mysql_connections << ::SpecClient.mysql(name)
      mysql_databases << name
    end

    files = Dir["#{File.dirname(__FILE__)}/../config/connections/elastisearch/*.yml"]
    files.each do |f|
      name = f.split('/').last.gsub('.yml','')
      elasticsearch_connections << ::SpecClient.elastisearch(name)
      elasticsearch_databases << name
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

end