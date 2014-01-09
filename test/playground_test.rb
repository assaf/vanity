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

  def test_be_failover_on_datastore_error
    assert !Vanity.playground.failover_on_datastore_error?
    Vanity.playground.failover_on_datastore_error!
    assert Vanity.playground.failover_on_datastore_error?
  end

  def test_default_failover_on_datastore_error
    proc = Vanity.playground.on_datastore_error
    assert proc.respond_to?(:call)
    assert_nothing_raised do
      proc.call(Exception.new("datastore error"), self.class, caller[0][/`.*'/][1..-2], [1, 2, 3])
    end
  end

  def test_request_filter
    proc = Vanity.playground.request_filter
    assert proc.respond_to?(:call)
    assert_nothing_raised do
      proc.call(dummy_request)
    end
  end

  def test_chooses_path_sets_default
    assert_equal Vanity.playground.add_participant_path, Vanity::Playground::DEFAULT_ADD_PARTICIPANT_PATH
  end

  def test_reconnects_with_existing_connection
    Vanity.playground.establish_connection "mock:/"
    Vanity.playground.reconnect!
    assert_equal Vanity.playground.connection.to_s, "mock:/"
  end

  def test_autoconnect_establishes_connection_by_default_with_connection
    instance = Vanity::Playground.new(:connection=>"mock:/")
    assert instance.connected?
  end

  def test_autoconnect_establishes_connection_by_default
    Vanity::Playground.any_instance.expects(:establish_connection)
    Vanity::Playground.new
  end

  def test_autoconnect_can_skip_connection
    Vanity::Autoconnect.stubs(:playground_should_autoconnect?).returns(false)
    instance = Vanity::Playground.new(:connection=>"mock:/")
    assert !instance.connected?
  end

  def test_experiments_persisted_returns_true
    metric "Coolness"
    new_ab_test :foobar do
      alternatives "foo", "bar"
      identify { "abcdef" }
      metrics :coolness
    end

    assert Vanity.playground.experiments_persisted?
  end

  def test_experiments_persisted_finds_returns_false
    name = 'Price'
    id = :price
    experiment = Vanity::Experiment::AbTest.new(Vanity.playground, id, name)
    Vanity.playground.experiments[id] = experiment

    assert !Vanity.playground.experiments_persisted?

    Vanity.playground.experiments.delete(id)
  end

  def test_participant_info
    assert_equal [], Vanity.playground.participant_info("abcdef")
    metric "Coolness"
    new_ab_test :foobar do
      alternatives "foo", "bar"
      identify { "abcdef" }
      metrics :coolness
    end
    alt = experiment(:foobar).choose
    assert_equal [[Vanity.playground.experiment(:foobar), alt]], Vanity.playground.participant_info("abcdef")
  end

end
