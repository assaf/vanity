require "test/test_helper"

class MetricTest < MiniTest::Unit::TestCase
  def setup
    super
    Vanity.context = mock("Context")
    Vanity.context.stubs(:vanity_identity).returns(rand)
  end
  
  # -- Via the playground --

  def test_playground_creates_metric_on_demand
    assert metric = Vanity.playground.metric(:on_demand)
    assert_equal :on_demand, metric.id
  end

  def test_playground_tracks_all_loaded_metrics
    Vanity.playground.metric(:work)
    Vanity.playground.metric(:play)
    assert_includes Vanity.playground.metrics.keys, :play
    assert_includes Vanity.playground.metrics.keys, :work
  end

  def test_playground_tracking_creates_metric_on_demand
    Vanity.playground.track! :on_demand
    assert_includes Vanity.playground.metrics.keys, :on_demand
    assert_respond_to Vanity.playground.metrics[:on_demand], :values
  end


  # -- Tracking --

  def test_tracking_can_count
    4.times { Vanity.playground.track! :play }
    2.times { Vanity.playground.track! :work }
    play = Vanity.playground.metric(:play).values(Date.today, Date.today).first
    work = Vanity.playground.metric(:work).values(Date.today, Date.today).first
    assert play = 2 * work
  end

  def test_tracking_can_tell_the_time
    Time.is (Date.today - 4).to_time do
      4.times { Vanity.playground.track! :play }
    end
    Time.is (Date.today - 2).to_time do
      2.times { Vanity.playground.track! :play }
    end
    1.times { Vanity.playground.track! :play }
    values = Vanity.playground.metric(:play).values(Date.today - 5, Date.today)
    assert_equal [0,4,0,2,0,1], values
  end


  # -- Tracking and hooks --

  def test_tracking_runs_hook
    returns = 0
    Vanity.playground.metric(:many_happy_returns).hook do |metric_id, timestamp, vanity_id|
      assert_equal :many_happy_returns, metric_id
      assert_in_delta Time.now.to_i, timestamp.to_i, 1
      assert_equal Vanity.context.vanity_identity, vanity_id
      returns += 1
    end
    Vanity.playground.track! :many_happy_returns
    assert_equal 1, returns
  end

  def test_tracking_runs_multiple_hooks
    returns = 0
    Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
    Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
    Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
    Vanity.playground.track! :many_happy_returns
    assert_equal 3, returns
  end


  # -- Title helper --
  
  def test_title_for_metric_with_title
    metric = Vanity.playground.metric(:bst)
    metric.title = "Blood, sweat, tears"
    assert_equal "Blood, sweat, tears", Vanity::Metric.title(:bst, metric)
  end

  def test_title_for_metric_with_no_title
    metric = Vanity.playground.metric(:bst)
    assert_equal "Bst", Vanity::Metric.title(:bst, metric)
  end

  def test_title_for_metric_with_no_title_attributes
    metric = Object.new
    assert_equal "Bst", Vanity::Metric.title(:bst, metric)
  end

  def test_title_for_metric_with_compound_id
    metric = Vanity.playground.metric(:blood_sweat_tears)
    assert_equal "Blood sweat tears", Vanity::Metric.title(:blood_sweat_tears, metric)
  end


  # -- Description helper --

  def test_description_for_metric_with_description
    metric = Vanity.playground.metric(:bst)
    metric.description = "I didn't say it will be easy"
    assert_equal "I didn't say it will be easy", Vanity::Metric.description(metric)
  end

  def test_description_for_metric_with_no_description
    metric = Vanity.playground.metric(:bst)
    assert_nil Vanity::Metric.description(metric)
  end

  def test_description_for_metric_with_no_description_method
    metric = Object.new
    assert_nil Vanity::Metric.description(metric)
  end


  # -- Metric bounds --

  def test_bounds_helper_for_metric_with_bounds
    metric = Vanity.playground.metric(:eggs)
    metric.instance_eval do
      def bounds ; [6,12] ; end
    end
    assert_equal [6,12], Vanity::Metric.bounds(metric)
  end

  def test_bounds_helper_for_metric_with_no_bounds
    metric = Vanity.playground.metric(:sky_is_limit)
    assert_equal [nil, nil], Vanity::Metric.bounds(metric)
  end

  def test_bounds_helper_for_metric_with_no_bounds_method
    metric = Object.new
    assert_equal [nil, nil], Vanity::Metric.bounds(metric)
  end

end
