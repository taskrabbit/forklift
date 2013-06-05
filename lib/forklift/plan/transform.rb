module Forklift 
  class Plan

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
        transform_sql({
          :file => file,
          :frequency => frequency
        })
      end
      Dir.glob("#{directory}/*.rb").each do |file|
        transform_ruby({
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

  end
end