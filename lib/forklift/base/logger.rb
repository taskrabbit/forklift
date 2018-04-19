require 'lumberjack'

module Forklift
  module Base
    class Logger

      def initialize(forklift)
        @forklift = forklift
      end

      def forklift
        @forklift
      end

      def messages
        @messages ||= []
      end

      def logger
        log_dir = "#{forklift.config[:project_root]}/log"
        @logger ||= case forklift.config[:logger][:output]
                      when :stdout
                        ::Lumberjack::Logger.new(Lumberjack::Device::Writer.new(STDOUT), buffer_size: 0)
                      else
                        ::Lumberjack::Logger.new("#{log_dir}/forklift.log", buffer_size: 0)
                    end
      end

      def log(message, severity="info")
        timed_message = "[Forklift @ #{Time.now}] #{message}"
        puts timed_message unless forklift.config[:logger][:stdout] != true
        logger.send(severity.to_sym, message) unless logger.nil?
        messages << timed_message
      end

      def debug(message)
        if forklift.config[:logger][:debug] == true
          log("[debug] #{message}")
        end
      end

      def emphatically(message)
        log "" if message.length > 0
        log "*** #{message} ***"
        log ""
      end

      def fatal(message)
        log "!!! #{message} !!!"
      end

    end
  end
end