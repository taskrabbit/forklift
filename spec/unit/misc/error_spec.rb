require 'spec_helper'

describe 'misc forklift core' do  
  describe 'error handling' do

    it "un-caught errors will raise" do
      plan = SpecPlan.new
      expect{
        plan.do! {
          plan.step("step_a"){ raise 'BREAK' }
        }
      }.to raise_error 'BREAK'
      plan.pid.delete!
    end

    it 'can make error handlers' do
      plan = SpecPlan.new
      name = ''
      ex   = ''
      error_handler = lambda{ |n, e| 
        ex   = e
        name = n
      }
      plan.do! {
        plan.step("step_a", error_handler){ raise 'BREAK' }
      }

      expect(name).to    eql :step_a
      expect(ex.to_s).to eql 'BREAK'
    end

  end
end