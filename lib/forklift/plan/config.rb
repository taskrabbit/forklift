require 'trollop'

module Forklift 
  class Plan

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
  
  end
end