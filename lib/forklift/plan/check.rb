module Forklift 
  class Plan
    
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

  end
end