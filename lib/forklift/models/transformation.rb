require 'find'

module Forklift
  class Transformation


    def initialize(connection, database, logger, forklift_data_table)
      @connection = connection
      @database = database
      @logger = logger
      @forklift_data_table = forklift_data_table
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

    def forklift_data_table
      @forklift_data_table
    end

    def transform_sql(file, frequency=nil)
      stat_time = Time.now
      if frequency_check(file, frequency)
        logger.log "Starting SQL transformation: #{file}"
        connection.q("use `#{database}`")
        contents = File.open(file, "r").read
        lines = contents.split(";")
        lines.each do |line|
          line.strip!
          begin
            connection.q(line, false) if line.length > 0
          rescue Exception => e
            logger.log "   !!! transformation error: #{e} !!! "
            logger.log "   moving on..."
          end
        end
        log_transformation(file)
        logger.log " ... took #{Time.new - stat_time}s"
      else
        logger.log "Skipping SQL transformation: #{file} because last run was too recently"
      end
    end

    def transform_ruby(file, frequency=nil)
      stat_time = Time.now
      klass = Forklift::Utils.class_name_from_file(file)
      if frequency_check(file, frequency)
        logger.log "Starting RUBY transformation: #{klass} @ #{file}"
        connection.q("use `#{database}`")
        begin
          require file
          transformation = eval("#{klass}.new")
          transformation.transform(connection, database, logger) unless Forklift::Argv.args[:debug] == true
        rescue Exception => e
          logger.log "   !!! transformation error: #{e} !!! "
          logger.log "   moving on..."
        end
        log_transformation(file)
        logger.log " ... took #{Time.new - stat_time}s"
      else
        logger.log "Skipping RUBY transformation: #{klass} @ #{file} because last run was too recently"
      end
    end

    private

    def frequency_check(file, frequency)
      return true if frequency.nil?
      timestamps = connection.q("select unix_timestamp(`created_at`) as 'time' from `#{database}`.`#{forklift_data_table}` where `name` =  '#{file}' and type='transformation'")
      return true if timestamps.nil?
      return true if timestamps.to_i + frequency <= Time.new.to_i
      return false
    end

    def log_transformation(file)
      connection.q("delete from `#{database}`.`#{forklift_data_table}` where name='#{file}' and type='transformation'")
      connection.q("insert into `#{database}`.`#{forklift_data_table}` (created_at, name, type) values (NOW(), '#{file}', 'transformation') ")
    end

    def class_name_from_file(file)
      klass = ""
      words = file.split("/").last.split(".").first.split("_")
      words.each do |word|
        klass << word.capitalize
      end
      klass
    end

  end
end