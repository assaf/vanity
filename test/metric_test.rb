require "test/test_helper"

class MetricTest < MiniTest::Unit::TestCase
  
  # -- Via the playground --

  def test_playground_creates_metric_on_demand
    assert metric = Vanity.playground.metric(:yawns_sec)
    assert_equal :yawns_sec, metric.id
  end

  def test_playground_tracks_all_loaded_metrics
    Vanity.playground.metric(:yawns_sec)
    Vanity.playground.metric(:cheers_sec)
    assert_includes Vanity.playground.metrics.keys, :yawns_sec
    assert_includes Vanity.playground.metrics.keys, :cheers_sec
  end

  def test_playground_tracking_creates_metric_on_demand
    Vanity.playground.track! :yawns_sec
    assert_includes Vanity.playground.metrics.keys, :yawns_sec
    assert_respond_to Vanity.playground.metrics[:yawns_sec], :values
  end

  def test_playground_loads_metric_definition
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "Yawns/sec" do
          def xmts
            "x"
          end
        end
      RUBY
    end
    assert_equal "x", Vanity.playground.metric(:yawns_sec).xmts
  end

  def test_metric_loading_handles_name_and_id
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "Yawns/sec" do
        end
      RUBY
    end
    assert metric = Vanity.playground.metric(:yawns_sec)
    assert_equal :yawns_sec, metric.id
    assert_equal "Yawns/sec", metric.name
  end

  def test_metric_loading_errors_bubble_up
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write "fail 'yawn!'"
    end
    assert_raises LoadError do
      Vanity.playground.metric(:yawns_sec)
    end
  end

  def test_metric_name_must_match_file_name
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "yawns/hour" do
        end
      RUBY
    end
    assert_raises LoadError do
      Vanity.playground.metric(:yawns_sec)
    end
  end

  def test_reloading_metrics
    Vanity.playground.metric(:yawns_sec)
    Vanity.playground.metric(:cheers_sec)
    assert 2, Vanity.playground.metrics.count
    Vanity.playground.reload!
    assert_empty Vanity.playground.metrics
  end


  # -- Tracking --

  def test_tracking_can_count
    4.times { Vanity.playground.track! :yawns_sec }
    2.times { Vanity.playground.track! :cheers_sec }
    yawns = Vanity.playground.metric(:yawns_sec).values(Date.today, Date.today).first
    cheers = Vanity.playground.metric(:cheers_sec).values(Date.today, Date.today).first
    assert yawns = 2 * cheers
  end

  def test_tracking_can_tell_the_time
    Timecop.travel Date.today - 4 do
      4.times { Vanity.playground.track! :yawns_sec }
    end
    Timecop.travel Date.today - 2 do
      2.times { Vanity.playground.track! :yawns_sec }
    end
    1.times { Vanity.playground.track! :yawns_sec }
    boredom = Vanity.playground.metric(:yawns_sec).values(Date.today - 5, Date.today)
    assert_equal [0,4,0,2,0,1], boredom
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


  # -- Name helper --
  
  def test_name_for_metric_with_name
    metric = Vanity.playground.metric(:bst)
    metric.name = "Blood, sweat, tears"
    assert_equal "Blood, sweat, tears", Vanity::Metric.name(:bst, metric)
  end

  def test_name_for_metric_with_no_name
    metric = Vanity.playground.metric(:bst)
    assert_equal "Bst", Vanity::Metric.name(:bst, metric)
  end

  def test_name_for_metric_with_no_name_attributes
    metric = Object.new
    assert_equal "Bst", Vanity::Metric.name(:bst, metric)
  end

  def test_name_for_metric_with_compound_id
    metric = Vanity.playground.metric(:blood_sweat_tears)
    assert_equal "Blood sweat tears", Vanity::Metric.name(:blood_sweat_tears, metric)
  end


  # -- Description helper --

  def test_description_for_metric_with_description
    metric = Vanity.playground.metric(:bst)
    metric.description "I didn't say it will be easy"
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
