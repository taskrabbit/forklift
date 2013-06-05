module Forklift
  class Config

    def initialize
      @data = {}
      set_defaults
    end

    def dos 
      {
        "before" => true,
        "checks" => true,
        "extract" => true,
        "transform" => true,
        "load" => true,
        "dump" => false,
        "email" => false,
        "after" => true,
      }
    end

    def defaults
      defaults = {
        :project_root => Dir.pwd,
        :lock_with_pid? => true,

        :final_database => nil,
        :working_database => nil,
        :local_connection => {},
        :remote_connections => [],

        :swap_table => '_swap',
        :forklift_data_table => '_forklift',
        
        :verbose? => true,
      }
      dos.each do |k,v|
        defaults["do_#{k}?".to_sym] = v
      end
      defaults
    end

    def set_defaults
      defaults.each do |k,v|
        set(k,v)
      end
    end

    def merge_with_argv
      dos.each do |k,v|
        if Forklift::Argv.args["#{k}_given".to_sym] == true
          @data["do_#{k}?".to_sym] = Forklift::Argv.args[k.to_sym] 
        end
      end
    end

    def data
      @data
    end

    def set(k,v)
      @data[k] = v
    end

    def get(k)
      @data[k]
    end

    def values
      values = []
      @data.each do |k,v|
        values << k
      end
      values
    end

  end
end