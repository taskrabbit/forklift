require 'lumberjack'

module Forklift 
  class Plan

    #######
    # RUN #
    #######

    def run
      logger.emphatically "Forklift Starting"

      lock_pidfile                # Ensure that only one instance of Forklift is running
      rebuild_working_database    # Ensure that the working database exists
      ensure_forklift_data_table  # Ensure that the metadata table for forklift exists (used for frequency calculations)
      
      run_checks                  # Preform any data integrity checks
      run_extractions             # Extact data from the life databases into the working database
      run_transformations         # Preform any Transformations
      run_load                    # Load the manipulated data into the final database
      
      save_dump                   # mySQLdump the new final database for safe keeping
      send_email                  # Email folks the status of this forklift
      unlock_pidfile              # Cleanup the pidfile so I can run next time

      logger.emphatically "Forklift Complete"
    end

    ######################
    # CONFIG AND LOGGING #
    ######################

    def config
      @config ||= {}
    end

    def logger(supplied_logger=nil)
      return @logger unless @logger.nil?
      if supplied_logger.nil?
        @logger = Forklift::Logger.new(config)
      else
        @logger = supplied_logger
      end
      return @logger
    end

    def display_settings
      logger.debug "Settings: "
      @config.values.each do |k|
        logger.debug "  > #{k}: #{@config.get(k)}"
      end
    end

    def pidfile
      @pidfile ||= Forklift::PidFile.new(config, logger)
    end

    ########
    # INIT #
    ########

    def initialize(args={})
      @config = Forklift::Config.new
      args.each do |k,v|
        @config.set(k,v)
      end

      @plan = {
        :check => {
          :local => [],
          :remote => [],
        },
        :extract => {
          :local => [],
          :remote => [],
        },
        :transform => {
          :sql => [],
          :ruby => []
        }
      }

      build_connections
    end 

    #################
    # CHECK ACTIONS #
    #################

    def check_local_source(args)
      @plan[:check][:local].push(args)
    end

    def check_remote_source(args)
      @plan[:check][:remote].push(args)
    end

    def run_checks
      if config.get(:do_checks?)
        logger.emphatically "running checks"
        @plan[:check][:local].each do |check|
          response = Forklift::CheckEvaluator.new.local(check, @connections[:local_connection], logger)
          logger.fatal "Local Check Failed: #{check}" if response == false
        end

        @plan[:check][:remote].each do |check|
          response = Forklift::CheckEvaluator.new.remote(check, @connections[check[:connection_name]], logger)
          logger.fatal "Remote Check Failed: #{check}" if response == false
        end
      end
    end

    ###################
    # EXTRACT ACTIONS #
    ###################

    def import_local_database(args)
      @plan[:extract][:local].push(args)
    end

    def import_remote_database(args)
      @plan[:extract][:remote].push(args)
    end

    def import_partial_local_database(args)
      #TODO
    end

    def import_partial_remote_database(args)
      #TODO
    end

    def run_extractions
      logger.emphatically "running extractions"

      if config.get(:do_extract?)
        @plan[:extract][:local].each do |extraction|
          from = extraction[:database]
          to = config.get(:working_database)
          skipped_tables = []
          skipped_tables = extraction[:skip] unless extraction[:skip].nil?
          to_prefix = false
          to_prefix = extraction[:prefix] unless extraction[:prefix].nil?
          frequency = nil
          frequency = extraction[:frequency] unless extraction[:frequency].nil?
          forklift_data_table = config.get(:forklift_data_table)
          @connections[:local_connection].local_copy_tables(from, to, skipped_tables, to_prefix, frequency, forklift_data_table)
        end

        @plan[:extract][:remote].each do |extraction|
          from = extraction[:database]
          to = config.get(:working_database)
          skipped_tables = []
          skipped_tables = extraction[:skip] unless extraction[:skip].nil?
          to_prefix = false
          to_prefix = extraction[:prefix] unless extraction[:prefix].nil?
          frequency = nil
          frequency = extraction[:frequency] unless extraction[:frequency].nil?
          forklift_data_table = config.get(:forklift_data_table)
          @connections[extraction[:connection_name]].remote_copy_tables(@connections[:local_connection], from, to, skipped_tables, to_prefix, frequency, forklift_data_table)
        end
      else
        logger.log "skipping..."
      end
    end

    #####################
    # TRANSFORM ACTIONS #
    #####################

    def transform_sql(args)
      @plan[:transform][:sql].push(args)
    end

    def transform_ruby(args)
      @plan[:transform][:ruby].push(args)
    end

    def transform_directory(args)
      directory = args[:directory]
      frequency = args[:frequency]
      Dir.glob("#{directory}/*.sql").each do |file|
        forklift.transform_sql({
          :file => file
          :frequency => frequency
        })
      end
      Dir.glob("#{directory}/*.rb").each do |file|
        forklift.transform_ruby({
          :file => file,
          :frequency => frequency
        })
      end
    end

    def template_transformation
      Forklift::Transformation.new(@connections[:local_connection], config.get(:working_database), logger, config.get(:forklift_data_table))
    end

    def run_transformations
      logger.emphatically "running transformations"

      if config.get(:do_transform?)
        @plan[:transform][:sql].each do |transformation|
          file = transformation[:file]
          frequency = nil
          frequency = transformation[:frequency] unless transformation[:frequency].nil?
          template_transformation.transform_sql(file, frequency)
        end

        @plan[:transform][:ruby].each do |transformation|
          file = transformation[:file]
          frequency = nil
          frequency = transformation[:frequency] unless transformation[:frequency].nil?
          template_transformation.transform_ruby(file, frequency)
        end
      else
        logger.log "skipping..."
      end
    end

    ################
    # BASE ACTIONS #
    ################

    def lock_pidfile
      if config.get(:lock_with_pid?)
        pidfile.ensure_not_already_running
        pidfile.store
      end
    end

    def unlock_pidfile
      if config.get(:lock_with_pid?)
        pidfile.delete
      end
    end

    def build_connections
      @connections = {}

      config.get(:remote_connections).each do |remote_connection|
        @connections[remote_connection[:name]] = Forklift::Connection.new(remote_connection[:name], remote_connection, logger, config.get(:threads))
      end
      @connections[:local_connection] = Forklift::Connection.new("local_connection", config.get(:local_connection), logger, config.get(:threads))
    end

    def ensure_forklift_data_table
      create_syntax = <<-SQL

      CREATE TABLE IF NOT EXISTS `#{config.get(:forklift_data_table)}` (
        `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
        `created_at` datetime DEFAULT NULL,
        `name` varchar(255) DEFAULT NULL,
        `type` varchar(255) DEFAULT NULL,
        PRIMARY KEY (`id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
      SQL
      logger.log "Ensuring forklift data table exists: #{config.get(:forklift_data_table)}"
      @connections[:local_connection].q("use `#{config.get(:final_database)}`")
      @connections[:local_connection].q(create_syntax)

      logger.log "Copying #{config.get(:forklift_data_table)} to the working database"
      @connections[:local_connection].q("drop table if exists `#{config.get(:working_database)}`.`#{config.get(:forklift_data_table)}`")
      @connections[:local_connection].q("create table `#{config.get(:working_database)}`.`#{config.get(:forklift_data_table)}` like `#{config.get(:final_database)}`.`#{config.get(:forklift_data_table)}`")
      @connections[:local_connection].q("insert into `#{config.get(:working_database)}`.`#{config.get(:forklift_data_table)}` select * from `#{config.get(:final_database)}`.`#{config.get(:forklift_data_table)}`")
    end

    def rebuild_working_database
      logger.log "Recreateding the working databse: #{config.get(:working_database)}"
      @connections[:local_connection].q("create database if not exists `#{config.get(:working_database)}`")
    end

    def run_load
      logger.log "Loading working set into #{config.get(:final_database)}"
      if config.get(:do_load?)
        @connections[:local_connection].direct_local_copy(config.get(:working_database), config.get(:final_database))
      end
    end

    def save_dump
      if config.get(:do_dump?)
        logger.emphatically "saving mysql dump"
        username = config.get(:local_connection)[:username]
        password = nil
        password = config.get(:local_connection)[:pasword] unless config.get(:local_connection)[:pasword].nil?
        database = config.get(:local_connection)[:database]
        file = config.get(:dump_file)
        dumper = Forklift::Dump.new(username, password, database, file, logger)
        dumper.run
      end
    end

    def send_email
      if config.get(:do_email?)
        emailer = Forklift::Email.new(config.get(:email_options), logger)
        config.get(:email_to).each do |recipient|
          logger.log "Emailing #{recipient}"
          emailer.send({:to => recipient}, true)
        end
      end
    end
    
  end
end