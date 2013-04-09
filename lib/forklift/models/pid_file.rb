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
    
    def pidfile
      "#{pid_dir}/pidfile"
    end
    
    def store
      logger.log "Creating pidfile @ #{pidfile}"
      `mkdir -p #{pid_dir}` 
      File.open(pidfile, 'w') {|f| f << Process.pid}
    end
    
    def recall
      `mkdir -p #{pid_dir}` 
      IO.read(pidfile).to_i rescue nil
    end
    
    def delete
      logger.log "Removing pidfile @ #{pidfile}"
      FileUtils.rm(pidfile) rescue nil
    end
    
    def ensure_not_already_running
      unless recall.nil?
        logger.fatal "This application is already running (pidfile). Exiting now"
      end
    end

  end
end