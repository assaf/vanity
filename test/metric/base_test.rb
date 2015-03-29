require "test_helper"

describe "Metric via playground" do

  it "knows all loaded metrics" do
    metric "Yawns/sec", "Cheers/sec"
    assert Vanity.playground.metrics.keys.include?(:yawns_sec)
    assert Vanity.playground.metrics.keys.include?(:cheers_sec)
  end

  it "loads metric definitions" do
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

  it "bubbles up loaded metrics" do
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write "fail 'yawn!'"
    end
    assert_raises NameError do
      Vanity.playground.metric(:yawns_sec)
    end
  end

  it "map identifier from file name" do
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "yawns/hour" do
        end
      RUBY
    end
    assert Vanity.playground.metric(:yawns_sec)
  end

  it "fails tracking unknown metric" do
    assert_raises NameError do
      Vanity.playground.track! :yawns_sec
    end
  end

  it "reloading metrics" do
    metric "Yawns/sec", "Cheers/sec"
    Vanity.playground.metric(:yawns_sec)
    Vanity.playground.metric(:cheers_sec)
    assert_equal 2, Vanity.playground.metrics.size
    metrics = Vanity.playground.metrics.values
    Vanity.playground.reload!
    assert_equal 0, Vanity.playground.metrics.size
    refute_equal metrics, Vanity.playground.metrics.values
  end

  it "ignores undefined metrics in database" do
    metric "Yawns/sec"
    Vanity.playground.reload!
    assert Vanity.playground.metrics.empty?
  end

  it "bootstraps the metric" do
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "yawns/hour" do
        end
      RUBY
    end
    Vanity.playground.track!(:yawns_sec)
    Vanity.playground.track!(:yawns_sec)
    assert Vanity.playground.connection.get_metric_last_update_at(:yawns_sec)
  end
end


describe "Metric tracking" do
  it "disabled when metrics are disabled" do
    not_collecting!
    metric "Yawns/sec", "Cheers/sec"
    Vanity.playground.track! :yawns_sec
    Vanity.playground.track! :cheers_sec
  end

  it "can count" do
    metric "Yawns/sec", "Cheers/sec"
    4.times { Vanity.playground.track! :yawns_sec }
    2.times { Vanity.playground.track! :cheers_sec }
    yawns = Vanity.playground.metric(:yawns_sec).values(today, today).first
    cheers = Vanity.playground.metric(:cheers_sec).values(today, today).first
    assert yawns == 2 * cheers
  end

  it "can tell the time" do
    metric "Yawns/sec"
    Timecop.freeze((today - 4).to_time) { 4.times { Vanity.playground.track! :yawns_sec } }
    Timecop.freeze((today - 2).to_time) { 2.times { Vanity.playground.track! :yawns_sec } }
    1.times { Vanity.playground.track! :yawns_sec }
    boredom = Vanity.playground.metric(:yawns_sec).values(today - 5, today)
    assert_equal [0,4,0,2,0,1], boredom
  end

  it "with no value" do
    metric "Yawns/sec", "Cheers/sec", "Looks"
    Vanity.playground.track! :yawns_sec, 0
    Vanity.playground.track! :cheers_sec
    assert_equal 0, Vanity.playground.metric(:yawns_sec).values(today, today).sum
    assert_equal 1, Vanity.playground.metric(:cheers_sec).values(today, today).sum
  end

  it "with count" do
    metric "Yawns/sec"
    Timecop.freeze((today - 4).to_time) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.freeze((today - 2).to_time) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity.playground.metric(:yawns_sec).values(today - 5, today)
    assert_equal [0,4,0,2,0,1], boredom
  end

  it "runs hook" do
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

  it "doesn't runs hook when metrics disabled" do
    not_collecting!
    metric "Many Happy Returns"
    total = 0
    Vanity.playground.metric(:many_happy_returns).hook do |metric_id, timestamp, count|
      total += count
    end
    Vanity.playground.track! :many_happy_returns, 6
    assert_equal 0, total
  end

  it "runs multiple hooks" do
    metric "Many Happy Returns"
    returns = 0
    Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
    Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
    Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
    Vanity.playground.track! :many_happy_returns
    assert_equal 3, returns
  end

  it "destroy wipes metrics" do
    metric "Many Happy Returns"
    Vanity.playground.track! :many_happy_returns, 3
    assert_equal [3], Vanity.playground.metric(:many_happy_returns).values(today, today)
    Vanity.playground.metric(:many_happy_returns).destroy!
    assert_equal [0], Vanity.playground.metric(:many_happy_returns).values(today, today)
  end
end


describe "Metric name" do
  it "can be whatever" do
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "Yawns per second" do
        end
      RUBY
    end
    assert_equal "Yawns per second", Vanity.playground.metric(:yawns_sec).name
  end
end


describe "Metric description" do
  it "metric with description" do
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "Yawns/sec" do
          description "Am I that boring?"
        end
      RUBY
    end
    assert_equal "Am I that boring?", Vanity::Metric.description(Vanity.playground.metric(:yawns_sec))
  end

  it "metric without description" do
    File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
      f.write <<-RUBY
        metric "Yawns/sec" do
        end
      RUBY
    end
    assert_nil Vanity::Metric.description(Vanity.playground.metric(:yawns_sec))
  end

  it "metric with no method description" do
    metric = Object.new
    assert_nil Vanity::Metric.description(metric)
  end
end


describe "Metric bounds" do
  it "metric with bounds" do
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

  it "metric without bounds" do
    metric "Sky is limit"
    assert_equal [nil, nil], Vanity::Metric.bounds(Vanity.playground.metric(:sky_is_limit))
  end

  it "metric with no method bounds" do
    metric = Object.new
    assert_equal [nil, nil], Vanity::Metric.bounds(metric)
  end
end


describe "Metric last_update_at" do
  it "for new metric" do
    metric "Coolness"
    metric = Vanity.playground.metric(:coolness)
    assert_nil metric.last_update_at
  end

  it "with data point" do
    metric "Coolness"
    metric = Vanity.playground.metric(:coolness)
    metric.track!
    Timecop.freeze Time.now + 1.day do
      metric.track!
    end
    assert_in_delta metric.last_update_at.to_i, (Time.now + 1.day).to_i, 1
  end
end


describe "Metric data" do
  it "explicit dates" do
    metric "Yawns/sec"
    Timecop.freeze((today - 4).to_time) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.freeze((today - 2).to_time) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), Date.today - 5, Date.today)
    assert_equal [[today - 5, 0], [today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
  end

  it "start date only" do
    metric "Yawns/sec"
    Timecop.freeze((today - 4).to_time) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.freeze((today - 2).to_time) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), Date.today - 4)
    assert_equal [[today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
  end

  it "start date and duration" do
    metric "Yawns/sec"
    Timecop.freeze((today - 4).to_time) { Vanity.playground.track! :yawns_sec, 4 }
    Timecop.freeze((today - 2).to_time) { Vanity.playground.track! :yawns_sec, 2 }
    Vanity.playground.track! :yawns_sec
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), 5)
    assert_equal [[today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
  end

  it "no data" do
    metric "Yawns/sec"
    boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec))
    assert_equal 90, boredom.size
    assert_equal [today - 89, 0], boredom.first
    assert_equal [today, 0], boredom.last
  end

  it "using custom values method" do
    File.open "tmp/experiments/metrics/hours_in_day.rb", "w" do |f|
      f.write <<-RUBY
        metric "Hours in day" do
          def values(from, to)
            (from..to).map { |d| 24 }
          end
        end
      RUBY
    end
    data = Vanity::Metric.data(Vanity.playground.metric(:hours_in_day))
    assert_equal [24] * 90, data.map(&:last)
  end
end
