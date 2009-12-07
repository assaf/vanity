require "test/test_helper"

class Sky < ActiveRecord::Base
  connection.drop_table :skies
  connection.create_table :skies do |t|
    t.integer :height
    t.timestamps
  end
end

class MetricTest < Test::Unit::TestCase
  
  def setup
    super
    Sky.delete_all
    Sky.after_create.clear
  end

  # -- Via the playground --

  def test_playground_tracks_all_loaded_metrics
    metric "Yawns/sec", "Cheers/sec"
    assert Vanity.playground.metrics.keys.include?(:yawns_sec)
    assert Vanity.playground.metrics.keys.include?(:cheers_sec)
  end

  def test_playground_fails_without_metric_file
    assert_raises NameError do
      Vanity.playground.track! :yawns_sec
    end
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

  def test_metric_loading_errors_bubble_up
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write "fail 'yawn!'"
    end
    assert_raises NameError do
      Vanity.playground.metric(:yawns_sec)
    end
  end

  def test_metric_identifier_from_file
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "yawns/hour" do
        end
      RUBY
    end
    assert Vanity.playground.metric(:yawns_sec)
  end

  def test_reloading_metrics
    metric "Yawns/sec", "Cheers/sec"
    Vanity.playground.metric(:yawns_sec)
    Vanity.playground.metric(:cheers_sec)
    assert 2, Vanity.playground.metrics.size
    metrics = Vanity.playground.metrics.values
    Vanity.playground.reload!
    assert 2, Vanity.playground.metrics.size
    assert_not_equal metrics, Vanity.playground.metrics.values
  end

  def test_undefined_metric_in_database
    metric "Yawns/sec"
    Vanity.playground.reload!
    assert Vanity.playground.metrics.empty?
  end


  # -- Tracking --

  def test_tracking_can_count
    metric "Yawns/sec", "Cheers/sec"
    4.times { Vanity.playground.track! :yawns_sec }
    2.times { Vanity.playground.track! :cheers_sec }
    yawns = Vanity.playground.metric(:yawns_sec).values(today, today).first
    cheers = Vanity.playground.metric(:cheers_sec).values(today, today).first
    assert yawns = 2 * cheers
  end

  def test_tracking_with_value
    metric "Yawns/sec", "Cheers/sec", "Looks"
    Vanity.playground.track! :yawns_sec, 0
    Vanity.playground.track! :cheers_sec, -1
    Vanity.playground.track! :looks, 10
    assert_equal 0, Vanity.playground.metric(:yawns_sec).values(today, today).sum
    assert_equal 0, Vanity.playground.metric(:cheers_sec).values(today, today).sum
    assert_equal 10, Vanity.playground.metric(:looks).values(today, today).sum
  end

  def test_tracking_can_tell_the_time
    metric "Yawns/sec"
    Timecop.travel(today - 4) { 4.times { Vanity.playground.track! :yawns_sec } }
    Timecop.travel(today - 2) { 2.times { Vanity.playground.track! :yawns_sec } }
    1.times { Vanity.playground.track! :yawns_sec }
    boredom = Vanity.playground.metric(:yawns_sec).values(today - 5, today)
    assert_equal [0,4,0,2,0,1], boredom
  end

  def test_tracking_with_count
    metric "Yawns/sec"
    Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity.playground.metric(:yawns_sec).values(today - 5, today)
    assert_equal [0,4,0,2,0,1], boredom
  end

  def test_tracking_runs_hook
    metric "Many Happy Returns"
    total = 0
    Vanity.playground.metric(:many_happy_returns).hook do |metric_id, timestamp, count|
      assert_equal :many_happy_returns, metric_id
      assert_in_delta Time.now.to_i, timestamp.to_i, 1
      total += count
    end
    Vanity.playground.track! :many_happy_returns, 6
    assert_equal 6, total
  end

  def test_tracking_runs_multiple_hooks
    metric "Many Happy Returns"
    returns = 0
    Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
    Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
    Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
    Vanity.playground.track! :many_happy_returns
    assert_equal 3, returns
  end

  def test_destroy_metric_wipes_data
    metric "Many Happy Returns"
    Vanity.playground.track! :many_happy_returns, 3
    assert_equal [3], Vanity.playground.metric(:many_happy_returns).values(today, today)
    Vanity.playground.metric(:many_happy_returns).destroy!
    assert_equal [0], Vanity.playground.metric(:many_happy_returns).values(today, today)
  end


  # -- Metric name --
  
  def test_name_can_be_whatever
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "Yawns per second" do
        end
      RUBY
    end
    assert_equal "Yawns per second", Vanity.playground.metric(:yawns_sec).name
  end


  # -- Description helper --

  def test_description_for_metric_with_description
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "Yawns/sec" do
          description "Am I that boring?"
        end
      RUBY
    end
    assert_equal "Am I that boring?", Vanity::Metric.description(Vanity.playground.metric(:yawns_sec))
  end

  def test_description_for_metric_with_no_description
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "Yawns/sec" do
        end
      RUBY
    end
    assert_nil Vanity::Metric.description(Vanity.playground.metric(:yawns_sec))
  end

  def test_description_for_metric_with_no_description_method
    metric = Object.new
    assert_nil Vanity::Metric.description(metric)
  end


  # -- Metric bounds --

  def test_bounds_helper_for_metric_with_bounds
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          def bounds
            [6,12]
          end
        end
      RUBY
    end
    assert_equal [6,12], Vanity::Metric.bounds(Vanity.playground.metric(:sky_is_limit))
  end

  def test_bounds_helper_for_metric_with_no_bounds
    metric "Sky is limit"
    assert_equal [nil, nil], Vanity::Metric.bounds(Vanity.playground.metric(:sky_is_limit))
  end

  def test_bounds_helper_for_metric_with_no_bounds_method
    metric = Object.new
    assert_equal [nil, nil], Vanity::Metric.bounds(metric)
  end


  # -- Timestamp --
  
  def test_metric_has_created_timestamp
    metric "Coolness"
    metric = Vanity.playground.metric(:coolness)
    assert_instance_of Time, metric.created_at
    assert_in_delta metric.created_at.to_i, Time.now.to_i, 1
  end
 
  def test_metric_keeps_created_timestamp_across_restarts
    past = Date.today - 1
    Timecop.travel past do
      metric "Coolness"
      coolness = Vanity.playground.metric(:coolness)
      assert_in_delta coolness.created_at.to_i, past.to_time.to_i, 1
    end

    new_playground
    metric "Coolness"
    new_cool = Vanity.playground.metric(:coolness)
    assert_in_delta new_cool.created_at.to_i, past.to_time.to_i, 1
  end


  # -- Data helper --

  def test_data_with_explicit_dates
    metric "Yawns/sec"
    Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), Date.today - 5, Date.today)
    assert_equal [[today - 5, 0], [today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
  end

  def test_data_with_start_date
    metric "Yawns/sec"
    Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), Date.today - 5)
    assert_equal [[today - 5, 0], [today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
  end

  def test_data_with_duration
    metric "Yawns/sec"
    Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), 5)
    assert_equal [[today - 5, 0], [today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
  end

  def test_data_with_no_dates
    metric "Yawns/sec"
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec))
    assert_equal [today - 90, 0], boredom.first
    assert_equal [today, 0], boredom.last
  end


  # -- ActiveRecord support --

  def test_active_record_count
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky
        end
      RUBY
    end
    Vanity.playground.metrics
    Sky.create!
    assert_equal 1, Sky.count
    assert_equal 1, Vanity::Metric.data(metric(:sky_is_limit)).last.last
  end

  def test_active_record_sum
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky, :height
        end
      RUBY
    end
    Vanity.playground.metrics
    Sky.create! :height=>4
    assert_equal 4, Sky.sum(:height)
    assert_equal 4, Vanity::Metric.data(metric(:sky_is_limit)).last.last
  end

  def test_active_record_callback
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky, :height
        end
      RUBY
    end
    Vanity.playground.metrics
    total = 0
    metric(:sky_is_limit).hook do |metric_id, timestamp, count|
      assert_equal :sky_is_limit, metric_id
      assert_in_delta Time.now.to_i, timestamp.to_i, 1
      total += count
    end
    Sky.create! :height=>4
    assert_equal 4, total
  end

  def test_active_record_after_create
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky
        end
      RUBY
    end
    Vanity.playground.metrics
    once = nil
    metric(:sky_is_limit).hook do
      fail "Metric tracked twice" if once
      once = true
    end
    Sky.create!
    Sky.last.update_attributes :height=>4
  end

  def test_active_record_disables_track!
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky
        end
      RUBY
    end
    Vanity.playground.metrics
    once = nil
    metric(:sky_is_limit).hook do
      fail "Metric tracked twice" if once
      once = true
    end
    Sky.create!
    metric(:sky_is_limit).track!
  end

  # -- Helper methods --

  def today
    @today ||= Date.today
  end

end
