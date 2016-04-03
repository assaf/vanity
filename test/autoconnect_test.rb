require "test_helper"

describe Vanity::Autoconnect do
  describe ".should_connect?" do
    it "returns true by default" do
      autoconnect = Vanity::Autoconnect.should_connect?
      assert autoconnect == true
    end

    it "returns false if environment flag is set" do
      ENV['VANITY_DISABLED'] = '1'
      autoconnect = Vanity::Autoconnect.should_connect?
      assert autoconnect == false
      ENV['VANITY_DISABLED'] = nil
    end

    it "returns false if in assets:precompile rake task" do
      Rake.expects(:application).returns(stub(:top_level_tasks => ['assets:precompile']))
      autoconnect = Vanity::Autoconnect.should_connect?
      assert autoconnect == false
    end
  end

  describe ".schema_relevant?" do
    it "returns true for database tasks" do
      Rake.expects(:application).returns(stub(:top_level_tasks => ['db:migrate']))
      assert_equal true, Vanity::Autoconnect.schema_relevant?
    end
  end
end