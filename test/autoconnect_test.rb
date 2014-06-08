require "test_helper"

describe Vanity::Autoconnect do
  describe ".playground_should_autoconnect?" do

    it "returns true by default" do
      autoconnect = Vanity::Autoconnect.playground_should_autoconnect?
      assert autoconnect == true
    end

    it "returns false if environment flag is set" do
      ENV['VANITY_DISABLED'] = '1'
      autoconnect = Vanity::Autoconnect.playground_should_autoconnect?
      assert autoconnect == false
      ENV['VANITY_DISABLED'] = nil
    end

    it "returns false if in assets:precompile rake task" do
      Rake.expects(:application).returns(stub(:top_level_tasks => ['assets:precompile']))
      autoconnect = Vanity::Autoconnect.playground_should_autoconnect?
      assert autoconnect == false
    end
  end
end