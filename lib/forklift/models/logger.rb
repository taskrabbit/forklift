require 'lumberjack'

module Forklift
  class Logger

    def initialize(config)
      @config = config
    end

    def config
      @config
    end

    def messages
      @messages ||= []
    end

    def logger 
      log_dir = "#{config.get(:project_root)}/log"
      @logger ||= ::Lumberjack::Logger.new("#{log_dir}/forklift.log", :buffer_size => 0)
    end

    def log(message, severity="info")
      timed_message = "[Forklift @ #{Time.now}] #{message}"
      puts timed_message
      logger.send(severity.to_sym, message) unless logger.nil?
      messages << timed_message
    end

    def debug(message)
      if config.get(:verbose?) == true
        log(message)
      elsif Forklift::Argv.args[:debug] == true
        log(message)
      end
    end

    def emphatically(message)
      log "" if messages.length > 0 
      log "*** #{message} ***"
      log ""
    end

    def fatal(message)
      log "!!! #{message} !!!"
      send_fatal_email(message)
      exit(1)
    end

    def send_fatal_email(message)
      if config.get(:do_email?)
        emailer = Forklift::Email.new(config.get(:email_options), self)
        config.get(:email_logs_to).each do |recipient|
          self.log "Emailing #{recipient}"
          emailer.send({:to => recipient, :subject => "Forklift Failed @ #{Time.new}", :body => "Forklift encountered an error: #{message}"}, true)
        end
      end
    end

  end
end