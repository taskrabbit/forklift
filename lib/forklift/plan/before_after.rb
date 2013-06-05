module Forklift 
  class Plan
    
    ##########################
    # BEFORE / AFTER ACTIONS #
    ##########################

    def before_sql(args)
      @plan[:before][:sql].push(args)
    end

    def before_ruby(args)
      @plan[:before][:ruby].push(args)
    end

    def after_sql(args)
      @plan[:after][:sql].push(args)
    end

    def after_ruby(args)
      @plan[:after][:ruby].push(args)
    end

    def before_directory(args)
      directory = args[:directory]
      Dir.glob("#{directory}/*.sql").each do |file|
        before_sql({
          :file => file,
        })
      end
      Dir.glob("#{directory}/*.rb").each do |file|
        before_ruby({
          :file => file,
        })
      end
    end

    def after_directory(args)
      directory = args[:directory]
      Dir.glob("#{directory}/*.sql").each do |file|
        after_sql({
          :file => file,
        })
      end
      Dir.glob("#{directory}/*.rb").each do |file|
        after_ruby({
          :file => file,
        })
      end
    end

    def template_before_after
      Forklift::BeforeAfter.new(@connections[:local_connection], config.get(:final_database), logger)
    end

    def run_before
      logger.emphatically "running before"

      if config.get(:do_before?)
        @plan[:before][:sql].each do |before|
          file = before[:file]
          template_before_after.before_sql(file)
        end

        @plan[:before][:ruby].each do |before|
          file = before[:file]
          template_before_after.before_ruby(file)
        end
      else
        logger.log "skipping..."
      end
    end

    def run_after
      logger.emphatically "running after"

      if config.get(:do_after?)
        @plan[:after][:sql].each do |after|
          file = after[:file]
          template_before_after.after_sql(file)
        end

        @plan[:after][:ruby].each do |after|
          file = after[:file]
          template_before_after.after_ruby(file)
        end
      else
        logger.log "skipping..."
      end
    end

  end
end