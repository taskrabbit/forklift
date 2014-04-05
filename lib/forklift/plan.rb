require 'active_support/all'

module Forklift
  class Plan

    def initialize(config={})
      @config      = default_config.merge(config)
      @utils       = Forklift::Base::Utils.new
      @pid         = Forklift::Base::Pid.new(self)
      @logger      = Forklift::Base::Logger.new(self)
      @mailer      = Forklift::Base::Mailer.new(self)
      @connections = {}
      @steps       = {}
    end

    def connections; @connections end
    def steps;       @steps       end
    def config;      @config      end
    def logger;      @logger      end
    def mailer;      @mailer      end
    def utils;       @utils       end
    def pid;         @pid         end

    def connect!
      files = Dir["#{config[:project_root]}/config/connections/**/*.yml"]
      files.each do |f|
        next if f.include?('example.yml')
        name = f.split("/")[-1].split('.')[0]
        type = f.split("/")[-2]
        connections[type.to_sym] = {} if connections[type.to_sym].nil?
        db_config = utils.load_yml(f)

        begin
          loader = "Forklift::Connection::#{type.camelcase}.new(db_config, self)"
          connection = eval(loader)
          connections[type.to_sym][name.to_sym] = connection
          logger.debug "loaded a #{type.camelcase} connection from #{f}"
        rescue Exception => e
          logger.fatal "cannot create a class type of #{loader} from #{f} | #{e}"
          raise e
        end
      end
    end

    def step(*args, &block)
      name = args[0].to_sym
      self.steps[name] = {
        :ran => false,
        :to_run => false,
        :block => block
      }
    end

    def do_step!(name)
      name = name.to_sym
      if self.steps[name].nil?
        self.logger.log "[error] step `#{name}` not found"
      else
        step = self.steps[name]
        if step[:ran] == true
          self.logger.log "step `#{name}` already ran"
        elsif step[:to_run] == false
          self.logger.log "skipping step `#{name}`"
        else
          self.logger.log "*** step: #{name} ***"
          step[:block].call
          step[:ran] = true
        end
      end
    end

    def activate_steps
      # all steps are run by default
      # step names are passed as ARGV
      # `forklift plan.rb` runs everything and `forklift plan.rb send_email` only sends the email
      if ARGV.length < 2
        self.steps.each do |k,v|
          self.steps[k][:to_run] = true
        end
      else
        i = 1
        while i < ARGV.length
          name = ARGV[i].to_sym
          unless self.steps[name].nil?
            self.steps[name][:to_run] = true
          else
            self.logger.log "[error] step `#{name}` not found"
            exit(1)
          end
          i = i + 1
        end
      end
    end

    def do!
      # you can use `plan.logger.log` in your plan for logging
      self.logger.log "Starting forklift"

      # use a pidfile to ensure that only one instance of forklift is running at a time; store the file if OK
      self.pid.safe_to_run?
      self.pid.store!

      # this will load all connections in /config/connections/#{type}/#{name}.yml into the plan.connections hash
      # and build all the connection objects (and try to connect in some cases)
      self.connect!

      yield # your stuff here!

      self.activate_steps
      self.steps.each do |k, v|
        do_step!(k)
      end

      # remove the pidfile
      self.logger.log "Completed forklift"
      self.pid.delete!
    end

    private

    def default_config
      return {
        :project_root => Dir.pwd,
        :logger => {
          :stdout => true,
          :debug => false,
        },
      }
    end

    #/private

  end
end
