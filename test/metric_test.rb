require "test/test_helper"

class MetricTest < MiniTest::Unit::TestCase
  
  # -- Via the playground --

  def test_playground_creates_metric_on_demand
    assert metric = Vanity.playground.metric(:yawns_sec)
    assert_equal "Yawns sec", metric.name
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
    metrics = Vanity.playground.metrics.values
    Vanity.playground.reload!
    assert 2, Vanity.playground.metrics.count
    refute_equal metrics, Vanity.playground.metrics.values
  end


  # -- Tracking --

  def test_tracking_can_count
    4.times { Vanity.playground.track! :yawns_sec }
    2.times { Vanity.playground.track! :cheers_sec }
    yawns = Vanity.playground.metric(:yawns_sec).values(today, today).first
    cheers = Vanity.playground.metric(:cheers_sec).values(today, today).first
    assert yawns = 2 * cheers
  end

  def test_tracking_can_tell_the_time
    Timecop.travel today - 4 do
      4.times { Vanity.playground.track! :yawns_sec }
    end
    Timecop.travel today - 2 do
      2.times { Vanity.playground.track! :yawns_sec }
    end
    1.times { Vanity.playground.track! :yawns_sec }
    boredom = Vanity.playground.metric(:yawns_sec).values(today - 5, today)
    assert_equal [0,4,0,2,0,1], boredom
  end

  def test_tracking_with_count
    Timecop.travel today - 4 do
      Vanity.playground.track! :yawns_sec, 4
    end
    Timecop.travel today - 2 do
      Vanity.playground.track! :yawns_sec, 2
    end
    Vanity.playground.track! :yawns_sec
    boredom = Vanity.playground.metric(:yawns_sec).values(today - 5, today)
    assert_equal [0,4,0,2,0,1], boredom
  end

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

  def test_destroy_metric_wipes_data
    Vanity.playground.track! :many_happy_returns, 3
    assert_equal [3], Vanity.playground.metric(:many_happy_returns).values(today, today)
    Vanity.playground.metric(:many_happy_returns).destroy!
    assert_equal [0], Vanity.playground.metric(:many_happy_returns).values(today, today)
  end


  # -- Metric name --
  
  def test_name_from_identifier
    assert_equal "Many happy returns", Vanity.playground.metric(:many_happy_returns).name
  end

  def test_name_from_definition
    File.open "tmp/experiments/metrics/yawns_hour.rb", "w" do |f|
      f.write <<-RUBY
        metric "Yawns/hour" do
        end
      RUBY
    end
    assert_equal "Yawns/hour", Vanity.playground.metric(:yawns_hour).name
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


  # -- Timestamp --
  
  def test_metric_has_created_timestamp
    metric = Vanity.playground.metric(:coolness)
    assert_instance_of Time, metric.created_at
    assert_in_delta metric.created_at.to_i, Time.now.to_i, 1
  end
 
  def test_metric_keeps_created_timestamp_across_restarts
    past = Date.today - 1
    Timecop.travel past do
      metric = Vanity.playground.metric(:coolness)
      assert_in_delta metric.created_at.to_i, past.to_time.to_i, 1
    end

    new_playground
    metric = Vanity.playground.metric(:coolness)
    assert_in_delta metric.created_at.to_i, past.to_time.to_i, 1
  end


  # -- Data helper --

  def test_data_with_explicit_dates
    Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), Date.today - 5, Date.today)
    assert_equal [[today - 5, 0], [today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
  end

  def test_data_with_start_date
    Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), Date.today - 5)
    assert_equal [[today - 5, 0], [today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
  end

  def test_data_with_duration
    Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), 5)
    assert_equal [[today - 5, 0], [today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
  end

  def test_data_with_no_dates
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec))
    assert_equal [today - 90, 0], boredom.first
    assert_equal [today, 0], boredom.last
  end


  def today
    @today ||= Date.today
  end
  
end
