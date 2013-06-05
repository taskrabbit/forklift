module Forklift
  module Argv

    def self.args
      @args ||= Trollop::options do
        opt :debug,        "Use debug mode"                      , :default => nil
        opt :names,        "specific set of named actions to run", :default => nil, :type => :string

        opt :checks    , "(overide) use checks" 
        opt :extract   , "(overide) use extract" 
        opt :transform , "(overide) use transform" 
        opt :load      , "(overide) use load" 
        opt :email     , "(overide) use email" 
        opt :dump      , "(overide) use dump" 
        opt :before    , "(overide) use before" 
        opt :after     , "(overide) use after" 
      end
    end

    def self.names
      return @names unless @names.nil?
      @names = []
      unless Forklift::Argv.args[:names].nil?
        Forklift::Argv.args[:names].split(",").each do |name|
          @names << name.strip
        end
      else
        @names = nil
      end
      @names
    end

  end
end