require 'spec_helper'

describe 'misc forklift core' do  

  describe 'pidfile' do
    it "can create a pidfile and will remove it when the plan is over" do
      plan = SpecPlan.new
      pid = "#{File.dirname(__FILE__)}/../../pid/pidfile"
      expect(File.exists?(pid)).to eql false
      plan.do! {
        expect(File.exists?(pid)).to eql true
        expect(File.read(pid).to_i).to eql Process.pid
      }
      plan.disconnect!
      expect(File.exists?(pid)).to eql false
    end

    it "will not run with an existing pidfile" do 
      plan = SpecPlan.new
      plan.pid.store!
      expect { plan.do! }.to raise_error SystemExit
      plan.pid.delete!
      plan.disconnect!
    end 
  end

end