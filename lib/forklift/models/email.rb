require 'pony'

module Forklift
  class Email

    def initialize(options, logger)
      Pony.options = options
      @logger = logger
    end

    def logger
      @logger
    end 

    def message_defaults
      {
        :from => "Forklift",
        :subject => "Forklift has moved your database @ #{Time.new}",
        :body => "Forklift has moved your database @ #{Time.new}",
      }
    end

    def send(args, send_log=true)
      params = message_defaults
      [:to, :from, :subject, :body].each do |i|
        params[i] = args[i] unless args[i].nil?
      end
      if send_log == true
        params[:attachments] = {"log.txt" => logger.messages.join("\r\n")}
      end
      deliver(params)
    end

    private 

    def deliver(params)
      if Forklift::Debug.debug? == true
        logger.log "Not sending emails in debug mode"
      else
        Pony.mail(params)
      end
    end

  end
end