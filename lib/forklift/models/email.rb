require 'pony'
require 'erb'

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

    def send_template(args, template_file, variables)
      renderer = ERB.new(File.read(template_file))
      binder = ERBBinding.new(variables)
      body = renderer.result(binder.get_binding)
      args[:body] = body
      send(args)
    end

    def send(args, send_log=false)
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
      if Forklift::Argv.args[:debug] == true
        logger.log "Not sending emails in debug mode"
      else
        logger.log "Emailing #{params[:to]} about `#{params[:subject]}`"
        params[:html_body] = to_html(params[:body]) if params[:html_body].nil?
        Pony.mail(params)
      end
    end

    def to_html(body)
      body.gsub!("\n", "<br />")
      body = "<pre>#{body}</pre>"
      body = "<font face=\"Courier New, Courier, monospace\">#{body}</font>"
      body
    end

    class ERBBinding
      def initialize(hash)
        hash.each do |k,v|
          v = v.gsub("'", " ") if v.class == String
          v = v.to_s.gsub("'", " ") if v.class == Terminal::Table
          eval("@#{k} = '#{v}'")
        end
      end

      def get_binding
        return binding()
      end
    end

  end
end