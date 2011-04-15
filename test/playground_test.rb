require "test/test_helper"

class PlaygroundTest < Test::Unit::TestCase

  def test_has_one_global_instance
    assert instance = Vanity.playground
    assert_equal instance, Vanity.playground
  end

  def test_be_bot_resistant
    assert !Vanity.playground.bot_resistant? 
    Vanity.playground.be_bot_resistant
    assert Vanity.playground.bot_resistant? 
  end

  def test_chooses_path_sets_default
    assert_equal Vanity.playground.add_participant_path, Vanity::Playground::DEFAULT_ADD_PARTICIPANT_PATH
  end

end
