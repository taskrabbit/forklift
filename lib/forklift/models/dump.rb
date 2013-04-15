module Forklift
  class Dump

    def initialize(username, password, database, file, logger)
      @username = username
      @password = password
      @file = file
      @database = database
      @logger = logger
    end

    def logger
      @logger
    end

    def file
      @file
    end

    def username
      @username
    end

    def password
      @password
    end

    def database
      @database
    end

    def run
      # mysqldump needs to be in $PATH
      return if Forklift::Debug.debug? == true

      cmd = "mysqldump" 
      cmd << " -u#{username}"
      cmd << " -p#{password}" unless password.nil?
      cmd << " --max_allowed_packet=512M"
      cmd << " #{database}"
      cmd << " | gzip > #{file}"
      logger.log "Dumping #{database} to #{file}"
      `#{cmd}`
    end

  end
end