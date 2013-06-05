require 'find'

module Forklift
  class BeforeAfter

    def initialize(connection, database, logger)
      @connection = connection
      @database = database
      @logger = logger
    end

    def logger
      @logger
    end 

    def connection
      @connection
    end

    def database
      @database
    end

    def run_sql(file, mode)
      stat_time = Time.now
      logger.log "Starting SQL #{mode}: #{file}"
      connection.q("use `#{database}`")
      contents = File.open(file, "r").read
      lines = contents.split(";")
      lines.each do |line|
        line.strip!
        begin
          connection.q(line, false) if line.length > 0
        rescue Exception => e
          logger.log "   !!! #{mode} error: #{e} !!! "
          logger.log "   moving on..."
        end
      end
      logger.log " ... took #{Time.new - stat_time}s"
    end

    def run_ruby(file, mode)
      stat_time = Time.now
      klass = Forklift::Utils.class_name_from_file(file)
      logger.log "Starting RUBY #{mode}: #{klass} @ #{file}"
      connection.q("use `#{database}`")
      begin
        require file
        model = eval("#{klass}.new")
        if defined? model.before 
          model.before(connection, database, logger) unless Forklift::Argv.args[:debug] == true
        elsif defined? model.after
          model.after(connection, database, logger) unless Forklift::Argv.args[:debug] == true
        else
          throw "no before or after defined in #{file}"
        end
      rescue Exception => e
        logger.log "   !!! before error: #{e} !!! "
        logger.log "   moving on..."
      end
      logger.log " ... took #{Time.new - stat_time}s"
    end

    def before_sql(file)
      run_sql(file, "before")
    end

    def after_sql(file)
      run_sql(file, "after")
    end

    def before_ruby(file)
      run_ruby(file, "before")
    end

    def after_ruby(file)
      run_ruby(file, "after")
    end
    
  end
end