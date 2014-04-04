require 'spec_helper'

describe Forklift::Connection::Mysql do
  describe "#safe_values" do
    subject { described_class.new({}, {}) }

    it "escapes one trailing backslash" do
      values = ["foo\\"]
      subject.send(:safe_values, values).should == "\"foo\\\\\""
    end

    it "escapes two trailing backslashes" do
      values = ["foo\\\\"]
      subject.send(:safe_values, values).should == "\"foo\\\\\\\""
    end
  end
end