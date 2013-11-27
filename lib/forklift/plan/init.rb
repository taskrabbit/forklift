module Forklift 
  class Plan

    ########
    # INIT #
    ########

    def initialize(args={})
      @config = Forklift::Config.new
      args.each do |k,v|
        @config.set(k,v)
      end
      @config.merge_with_argv

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
        },
        :before => {
          :sql => [],
          :ruby => []
        },
        :after => {
          :sql => [],
          :ruby => []
        }, 
        :templated_emails => {
          :emails => []
        },
      }

      build_connections
    end 

    def determine_what_to_run
      unless Forklift::Argv.names.nil?
        logger.emphatically "running only the following named actions: #{Forklift::Argv.names.join(", ")}"
        @plan.keys.each do |key|
          collection = @plan[key]
          collection.keys.each do |type|
            typed_collection = collection[type]
            counter = 0

            typed_collection.each do |elem|
              if Forklift::Argv.names.include?( elem[:name] )
                # puts " > Will Run #{elem[:name]}"
              else
                puts " > Skipping #{elem[:name]}"
                @plan[key][type][counter] = nil
              end
              counter = counter + 1
            end
            @plan[key][type].compact! 
          end
        end
      end
    end

  end
end