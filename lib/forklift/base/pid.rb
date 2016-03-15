module Forklift
  module Base
    class Pid

      def initialize(forklift)
        @forklift = forklift
      end

      def forklift
        @forklift
      end

      def pid_dir
        "#{forklift.config[:project_root]}/pid"
      end

      def ensure_pid_dir
        `mkdir -p #{pid_dir}`
      end

      def pidfile
        "#{pid_dir}/pidfile"
      end

      def store!
        forklift.logger.debug "Creating pidfile @ #{pidfile}"
        ensure_pid_dir
        File.open(pidfile, 'w') {|f| f << Process.pid}
      end

      def recall
        ensure_pid_dir
        IO.read(pidfile).to_i rescue nil
      end

      def delete!
        forklift.logger.debug "Removing pidfile @ #{pidfile}"
        FileUtils.rm(pidfile) rescue nil
      end

      def safe_to_run?
        return if recall.nil?
        count = `ps -p #{recall} | wc -l`.to_i
        if count >= 2
          forklift.logger.fatal "This application is already running (pidfile) #{recall}. Exiting now"
          exit(1)
        else
          forklift.logger.log "Clearing old pidfile from previous process #{recall}"
          delete!
        end
      end

    end
  end
end
