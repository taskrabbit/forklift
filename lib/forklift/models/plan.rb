module Forklift 
  class Plan

    #######
    # RUN #
    #######

    def run
      logger.emphatically "Forklift Starting"
      logger.emphatically "RUNNING IN DEBUG MORE" if Forklift::Argv.args[:debug] == true

      lock_pidfile                # Ensure that only one instance of Forklift is running
      determine_what_to_run       # Should we run every part of the plan, or only some?
      rebuild_working_database    # Ensure that the working database exists
      ensure_forklift_data_table  # Ensure that the metadata table for forklift exists (used for frequency calculations)
      
      run_checks                  # Preform any data integrity checks
      run_before                  # Run any setup actions
      run_extractions             # Extact data from the life databases into the working database
      run_transformations         # Preform any Transformations
      run_load                    # Load the manipulated data into the final database
      run_after                   # Run any conclustion actions
      
      save_dump                   # mySQLdump the new final database for safe keeping
      send_emails                 # Email folks the status of this forklift and send any status emails
      unlock_pidfile              # Cleanup the pidfile so I can run next time

      logger.emphatically "Forklift Complete"
    end
    
  end
end

# Load all parts of the Plan
Dir[File.dirname(__FILE__) + '/../plan/*.rb'].each { |file| require file }