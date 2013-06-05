module Forklift 
  class Plan

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

      logger.log "Copying Forklift metadata table, `#{config.get(:forklift_data_table)}`, to the working database"
      @connections[:local_connection].q("drop table if exists `#{config.get(:working_database)}`.`#{config.get(:forklift_data_table)}`")
      @connections[:local_connection].q("create table `#{config.get(:working_database)}`.`#{config.get(:forklift_data_table)}` like `#{config.get(:final_database)}`.`#{config.get(:forklift_data_table)}`")
      @connections[:local_connection].q("insert into `#{config.get(:working_database)}`.`#{config.get(:forklift_data_table)}` select * from `#{config.get(:final_database)}`.`#{config.get(:forklift_data_table)}`")
    end

    def rebuild_working_database
      logger.log "Recreateding the working databse: #{config.get(:working_database)}"
      @connections[:local_connection].q("create database if not exists `#{config.get(:working_database)}`")
    end

    def run_load
      logger.emphatically "running load"
      if !Forklift::Argv.names.nil? && !Forklift::Argv.names.include?("LOAD") && !Forklift::Argv.names.include?("load")
        # do nothing
      else    
        logger.log "Loading working set into #{config.get(:final_database)}"
        if config.get(:do_load?)
          @connections[:local_connection].local_copy_with_swap(config.get(:working_database), config.get(:final_database), config.get(:swap_table))
        end
      end
    end

    def save_dump
      logger.emphatically "running dump"
      if !Forklift::Argv.names.nil? && !Forklift::Argv.names.include?("DUMP") && !Forklift::Argv.names.include?("dump")
        # do nothing
      else
        if config.get(:do_dump?)
          username = config.get(:local_connection)[:username]
          password = nil
          password = config.get(:local_connection)[:password] unless config.get(:local_connection)[:password].nil?
          database = config.get(:final_database)
          file = config.get(:dump_file)
          logger.emphatically "saving mysql dump to #{file}"
          dumper = Forklift::Dump.new(username, password, database, file, logger)
          dumper.run
        end
      end
    end

    def send_emails
      if config.get(:do_email?)
        emailer = Forklift::Email.new(config.get(:email_options), logger)
        send_templated_emails(emailer)
        unless config.get(:email_logs_to).nil?
          config.get(:email_logs_to).each do |recipient|
            emailer.send({:to => recipient}, true)
          end
        end
      end
    end

  end
end