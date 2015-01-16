require 'spec_helper'

describe 'misc forklift core' do  
  describe 'steps' do

    before(:each) do 
      ENV['FORKLIFT_RUN_ALL_STEPS'] = 'false'
    end

    after(:each) do
      ENV['FORKLIFT_RUN_ALL_STEPS'] = 'true'
    end

    it "will run all steps with no extra ARGV" do
      plan = SpecPlan.new
      allow(plan).to receive(:argv){ ['/path/to/plan'] }
      steps_run = []
      plan.do! {
        plan.step("a"){ steps_run << 'a' }
        plan.step("b"){ steps_run << 'b' }
        plan.step("c"){ steps_run << 'c' }
      }
      plan.disconnect!
      expect(steps_run).to include 'a'
      expect(steps_run).to include 'b'
      expect(steps_run).to include 'c'
    end

    it "will only run steps named within ARGV" do
      plan = SpecPlan.new
      allow(plan).to receive(:argv){ ['/path/to/plan', 'a','c'] }
      steps_run = []
      plan.do! {
        plan.step("a"){ steps_run << 'a' }
        plan.step("b"){ steps_run << 'b' }
        plan.step("c"){ steps_run << 'c' }
      }
      plan.disconnect!
      expect(steps_run).to include 'a'
      expect(steps_run).to_not include 'b'
      expect(steps_run).to include 'c'
    end

    it "won't run on a badly defined step" do
      plan = SpecPlan.new
      allow(plan).to receive(:argv){ ['/path/to/plan', 'missing_step'] }
      expect{
        plan.do! {
          plan.step("a"){ raise 'never should get here' }
        }
        plan.disconnect!
      }.to raise_error SystemExit
    end
  end

end