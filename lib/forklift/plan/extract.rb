module Forklift 
  class Plan

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
          this_conn = @connections[:local_connection]

          from = extraction[:database]
          to = config.get(:working_database)

          skipped_tables = []
          skipped_tables = extraction[:skip] unless extraction[:skip].nil?          
          skipped_tables = this_conn.only_list_to_skip_list(extraction[:database], extraction[:only]) unless extraction[:only].nil?
          
          to_prefix = false
          to_prefix = extraction[:prefix] unless extraction[:prefix].nil?
          
          frequency = nil
          frequency = extraction[:frequency] unless extraction[:frequency].nil?
          
          forklift_data_table = config.get(:forklift_data_table)
          this_conn.local_copy_tables(from, to, skipped_tables, to_prefix, frequency, forklift_data_table)
        end

        @plan[:extract][:remote].each do |extraction|
          this_conn = @connections[extraction[:connection_name]]

          from = extraction[:database]
          to = config.get(:working_database)

          skipped_tables = []
          skipped_tables = extraction[:skip] unless extraction[:skip].nil?
          skipped_tables = @connections[extraction[:connection_name]].only_list_to_skip_list(extraction[:database], extraction[:only]) unless extraction[:only].nil?
          
          to_prefix = false
          to_prefix = extraction[:prefix] unless extraction[:prefix].nil?
          
          frequency = nil
          frequency = extraction[:frequency] unless extraction[:frequency].nil?
          
          forklift_data_table = config.get(:forklift_data_table)
          this_conn.remote_copy_tables(@connections[:local_connection], from, to, skipped_tables, to_prefix, frequency, forklift_data_table)
        end
      else
        logger.log "skipping..."
      end
    end

  end
end