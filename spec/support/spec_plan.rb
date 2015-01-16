class SpecPlan
  def self.config
    return {
      project_root: File.join(Dir.pwd, 'spec'),
      logger: {
        stdout: false,
        debug: false,
      },
    }
  end

  def self.new
    return Forklift::Plan.new(self.config)
  end
end