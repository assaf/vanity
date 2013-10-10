require "test/test_helper"

class PlaygroundTest < Test::Unit::TestCase

  def test_has_one_global_instance
    assert instance = Vanity.playground
    assert_equal instance, Vanity.playground
  end

  def test_be_use_js
    assert !Vanity.playground.using_js?
    Vanity.playground.use_js!
    assert Vanity.playground.using_js?
  end

  def test_chooses_path_sets_default
    assert_equal Vanity.playground.add_participant_path, Vanity::Playground::DEFAULT_ADD_PARTICIPANT_PATH
  end

  def test_reconnects_with_existing_connection
    Vanity.playground.establish_connection "mock:/"
    Vanity.playground.reconnect!
    assert_equal Vanity.playground.connection.to_s, "mock:/"
  end

  def test_autoconnect_establishes_connection_by_default
    instance = Vanity::Playground.new(:connection=>"mock:/")
    assert instance.connected?
  end

  def test_autoconnect_can_skip_connection
    Vanity::Autoconnect.stubs(:playground_should_autoconnect?).returns(false)
    instance = Vanity::Playground.new(:connection=>"mock:/")
    assert !instance.connected?
  end

end
