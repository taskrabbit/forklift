module Forklift
  class PidFile

    def initialize(config, logger)
      @config = config
      @logger = logger
    end

    def logger 
      @logger
    end

    def pid_dir
      "#{@config.get(:project_root)}/pids"
    end

    def ensure_pid_dir
      `mkdir -p #{pid_dir}`
    end
    
    def pidfile
      "#{pid_dir}/pidfile"
    end
    
    def store
      logger.log "Creating pidfile @ #{pidfile}"
      ensure_pid_dir
      File.open(pidfile, 'w') {|f| f << Process.pid}
    end
    
    def recall
      ensure_pid_dir
      IO.read(pidfile).to_i rescue nil
    end
    
    def delete
      logger.log "Removing pidfile @ #{pidfile}"
      FileUtils.rm(pidfile) rescue nil
    end
    
    def ensure_not_already_running
      return if recall.nil?
      count = `ps -p #{recall} | wc -l`.to_i
      if count == 2
        logger.fatal "This application is already running (pidfile) #{recall}. Exiting now"
      else
        logger.log "Clearing old pidfile from previous process #{recall}"
        delete
      end
    end

  end
end