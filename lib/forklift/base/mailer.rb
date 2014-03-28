require 'pony'
require 'erb'

module Forklift
  module Base
    class Mailer

      def initialize(forklift)
        @forklift = forklift
      end

      # Public: Pull out the settings from config/email.yml.
      #
      # Returns a Hash with all symbolized keys.
      def config
        config_file = "#{forklift.config[:project_root]}/config/email.yml"
        @config ||= forklift.utils.load_yml(config_file).deep_symbolize_keys
      end

      def forklift
        @forklift
      end

      def message_defaults
        {
          :from => "Forklift",
          :subject => "Forklift has moved your database @ #{Time.new}",
          :body => "Forklift has moved your database @ #{Time.new}",
        }
      end

      def send_template(args, template_file, variables, attachment_lines)
        renderer = ERB.new(File.read(template_file))
        binder = ERBBinding.new(variables)
        body = renderer.result(binder.get_binding)
        args[:body] = body
        send(args, attachment_lines)
      end

      def send(args, attachment_lines=[])
        params = message_defaults
        [:to, :from, :subject, :body].each do |i|
          params[i] = args[i] unless args[i].nil?
        end
        if attachment_lines.length > 0
          params[:attachments] = {"log.txt" => attachment_lines.join("\r\n")}
        end
        deliver(params)
      end

      private

      # Private: Actually deliver the message using Pony.
      #
      # Returns the raw email from Pony.
      def deliver(params)
        forklift.logger.log("Sending email via #{config[:via]}")
        if params[:html_body].nil?
          params[:html_body] = params[:body]
          params.delete(:body)
        end
        params[:via] = config[:via]
        params[:via_options] = config[:via_options]
        Pony.mail(params)
      end

      class ERBBinding
        def initialize(hash)
          hash.each do |k,v|
            v = v.gsub("'", " ") if v.class == String
            instance_variable_set("@#{k}", v)
          end
        end

        def get_binding
          return binding()
        end
      end

    end
  end
end
