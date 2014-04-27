require "test_helper"

context ".playground_should_autoconnect?" do

  test "returns true by default" do
    autoconnect = Vanity::Autoconnect.playground_should_autoconnect?
    assert autoconnect == true
  end

  test "returns false if environment flag is set" do
    ENV['VANITY_DISABLED'] = '1'
    autoconnect = Vanity::Autoconnect.playground_should_autoconnect?
    assert autoconnect == false
    ENV['VANITY_DISABLED'] = nil
  end

  test "returns false if in assets:precompile rake task" do
    Rake.expects(:application).returns(stub(:top_level_tasks => ['assets:precompile']))
    autoconnect = Vanity::Autoconnect.playground_should_autoconnect?
    assert autoconnect == false
  end
end
