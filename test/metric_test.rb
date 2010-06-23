require "test/test_helper"

class Sky < ActiveRecord::Base
  connection.drop_table :skies if table_exists?
  connection.create_table :skies do |t|
    t.integer :height
    t.timestamps
  end

  named_scope :high, lambda { { :conditions=>"height >= 4" } }
end


context "Metric" do

  # -- Via the playground --

  context "playground" do

    test "knows all loaded metrics" do
      metric "Yawns/sec", "Cheers/sec"
      assert Vanity.playground.metrics.keys.include?(:yawns_sec)
      assert Vanity.playground.metrics.keys.include?(:cheers_sec)
    end

    test "loads metric definitions" do
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

    test "bubbles up loaded metrics" do
      File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
        f.write "fail 'yawn!'"
      end
      assert_raises NameError do
        Vanity.playground.metric(:yawns_sec)
      end
    end

    test "map identifier from file name" do
      File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
        f.write <<-RUBY
          metric "yawns/hour" do
          end
        RUBY
      end
      assert Vanity.playground.metric(:yawns_sec)
    end

    test "fails tracking unknown metric" do
      assert_raises NameError do
        Vanity.playground.track! :yawns_sec
      end
    end

    test "reloading metrics" do
      metric "Yawns/sec", "Cheers/sec"
      Vanity.playground.metric(:yawns_sec)
      Vanity.playground.metric(:cheers_sec)
      assert_equal 2, Vanity.playground.metrics.size
      metrics = Vanity.playground.metrics.values
      Vanity.playground.reload!
      assert_equal 0, Vanity.playground.metrics.size
      assert_not_equal metrics, Vanity.playground.metrics.values
    end

    test "ignores undefined metrics in database" do
      metric "Yawns/sec"
      Vanity.playground.reload!
      assert Vanity.playground.metrics.empty?
    end

  end


  # -- Tracking --

  context "tracking" do
    test "can count" do
      metric "Yawns/sec", "Cheers/sec"
      4.times { Vanity.playground.track! :yawns_sec }
      2.times { Vanity.playground.track! :cheers_sec }
      yawns = Vanity.playground.metric(:yawns_sec).values(today, today).first
      cheers = Vanity.playground.metric(:cheers_sec).values(today, today).first
      assert yawns = 2 * cheers
    end

    test "can tell the time" do
      metric "Yawns/sec"
      Timecop.travel(today - 4) { 4.times { Vanity.playground.track! :yawns_sec } }
      Timecop.travel(today - 2) { 2.times { Vanity.playground.track! :yawns_sec } }
      1.times { Vanity.playground.track! :yawns_sec }
      boredom = Vanity.playground.metric(:yawns_sec).values(today - 5, today)
      assert_equal [0,4,0,2,0,1], boredom
    end

    test "with no value" do
      metric "Yawns/sec", "Cheers/sec", "Looks"
      Vanity.playground.track! :yawns_sec, 0
      Vanity.playground.track! :cheers_sec, -1
      Vanity.playground.track! :looks, 10
      assert_equal 0, Vanity.playground.metric(:yawns_sec).values(today, today).sum
      assert_equal 0, Vanity.playground.metric(:cheers_sec).values(today, today).sum
      assert_equal 10, Vanity.playground.metric(:looks).values(today, today).sum
    end

    test "with count" do
      metric "Yawns/sec"
      Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
      Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
      Vanity.playground.track! :yawns_sec
      boredom = Vanity.playground.metric(:yawns_sec).values(today - 5, today)
      assert_equal [0,4,0,2,0,1], boredom
    end

    test "runs hook" do
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

    test "runs multiple hooks" do
      metric "Many Happy Returns"
      returns = 0
      Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
      Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
      Vanity.playground.metric(:many_happy_returns).hook { returns += 1 }
      Vanity.playground.track! :many_happy_returns
      assert_equal 3, returns
    end

    test "destroy wipes metrics" do
      metric "Many Happy Returns"
      Vanity.playground.track! :many_happy_returns, 3
      assert_equal [3], Vanity.playground.metric(:many_happy_returns).values(today, today)
      Vanity.playground.metric(:many_happy_returns).destroy!
      assert_equal [0], Vanity.playground.metric(:many_happy_returns).values(today, today)
    end
  end


  # -- Metric name --

  context "name" do
    test "can be whatever" do
      File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
        f.write <<-RUBY
          metric "Yawns per second" do
          end
        RUBY
      end
      assert_equal "Yawns per second", Vanity.playground.metric(:yawns_sec).name
    end
  end  


  # -- Description helper --

  context "description" do
    test "metric with description" do
      File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
        f.write <<-RUBY
          metric "Yawns/sec" do
            description "Am I that boring?"
          end
        RUBY
      end
      assert_equal "Am I that boring?", Vanity::Metric.description(Vanity.playground.metric(:yawns_sec))
    end

    test "metric without description" do
      File.open "tmp/experiments/metrics/yawns_sec.rb", "w" do |f|
        f.write <<-RUBY
          metric "Yawns/sec" do
          end
        RUBY
      end
      assert_nil Vanity::Metric.description(Vanity.playground.metric(:yawns_sec))
    end

    test "metric with no method description" do
      metric = Object.new
      assert_nil Vanity::Metric.description(metric)
    end
  end


  # -- Metric bounds --

  context "bounds" do
    test "metric with bounds" do
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

    test "metric without bounds" do
      metric "Sky is limit"
      assert_equal [nil, nil], Vanity::Metric.bounds(Vanity.playground.metric(:sky_is_limit))
    end

    test "metric with no method bounds" do
      metric = Object.new
      assert_equal [nil, nil], Vanity::Metric.bounds(metric)
    end
  end


  # -- Timestamp --
 
  context "created_at" do
    test "for new metric" do
      metric "Coolness"
      metric = Vanity.playground.metric(:coolness)
      assert_instance_of Time, metric.created_at
      assert_in_delta metric.created_at.to_i, Time.now.to_i, 1
    end

    test "across restarts" do
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
  end 


  # -- Data --

  context "data" do
    test "explicit dates" do
      metric "Yawns/sec"
      Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
      Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
      Vanity.playground.track! :yawns_sec
      boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), Date.today - 5, Date.today)
      assert_equal [[today - 5, 0], [today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
    end

    test "start date only" do
      metric "Yawns/sec"
      Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
      Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
      Vanity.playground.track! :yawns_sec
      boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), Date.today - 4)
      assert_equal [[today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
    end

    test "start date and duration" do
      metric "Yawns/sec"
      Timecop.travel(today - 4) { Vanity.playground.track! :yawns_sec, 4 }
      Timecop.travel(today - 2) { Vanity.playground.track! :yawns_sec, 2 }
      Vanity.playground.track! :yawns_sec
      boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec), 5)
      assert_equal [[today - 4, 4], [today - 3, 0], [today - 2, 2], [today - 1, 0], [today, 1]], boredom
    end

    test "no data" do
      metric "Yawns/sec"
      boredom = Vanity::Metric.data(Vanity.playground.metric(:yawns_sec))
      assert_equal 90, boredom.size
      assert_equal [today - 89, 0], boredom.first
      assert_equal [today, 0], boredom.last
    end

    test "using custom values method" do
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


  # -- ActiveRecord --

  context "ActiveRecord" do

    test "record count" do
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

    test "record sum" do
      File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
        f.write <<-RUBY
          metric "Sky is limit" do
            model Sky, :sum=>:height
          end
        RUBY
      end
      Vanity.playground.metrics
      Sky.create! :height=>4
      Sky.create! :height=>2
      assert_equal 6, Vanity::Metric.data(metric(:sky_is_limit)).last.last
    end

    test "record average" do
      Sky.aggregates
      File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
        f.write <<-RUBY
          metric "Sky is limit" do
            model Sky, :average=>:height
          end
        RUBY
      end
      Vanity.playground.metrics
      Sky.create! :height=>4
      Sky.create! :height=>2
      assert_equal 3, Vanity::Metric.data(metric(:sky_is_limit)).last.last
    end

    test "record minimum" do
      Sky.aggregates
      File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
        f.write <<-RUBY
          metric "Sky is limit" do
            model Sky, :minimum=>:height
          end
        RUBY
      end
      Vanity.playground.metrics
      Sky.create! :height=>4
      Sky.create! :height=>2
      assert_equal 2, Vanity::Metric.data(metric(:sky_is_limit)).last.last
    end

    test "record maximum" do
      Sky.aggregates
      File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
        f.write <<-RUBY
          metric "Sky is limit" do
            model Sky, :maximum=>:height
          end
        RUBY
      end
      Vanity.playground.metrics
      Sky.create! :height=>4
      Sky.create! :height=>2
      assert_equal 4, Vanity::Metric.data(metric(:sky_is_limit)).last.last
    end

    test "with conditions" do
      File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
        f.write <<-RUBY
          metric "Sky is limit" do
            model Sky, :sum=>:height, :conditions=>["height > 4"]
          end
        RUBY
      end
      Vanity.playground.metrics
      high_skies = 0
      metric(:sky_is_limit).hook do |metric_id, timestamp, height|
        assert height > 4
        high_skies += height
      end
      [nil,5,3,6].each do |height|
        Sky.create! :height=>height
      end
      assert_equal 11, Vanity::Metric.data(metric(:sky_is_limit)).sum(&:last)
      assert_equal 11, high_skies
    end

    test "with scope" do
      Sky.aggregates
      File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
        f.write <<-RUBY
          metric "Sky is limit" do
            model Sky.high
          end
        RUBY
      end
      Vanity.playground.metrics
      total = 0
      metric(:sky_is_limit).hook do |metric_id, timestamp, count|
        total += count
      end
      Sky.create! :height=>4
      Sky.create! :height=>2
      assert_equal 1, Vanity::Metric.data(metric(:sky_is_limit)).last.last
      assert_equal 1, total
    end

    test "hooks" do
      File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
        f.write <<-RUBY
          metric "Sky is limit" do
            model Sky, :sum=>:height
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

    test "after_create not after_save" do
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

    test "with after_save" do
      File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
        f.write <<-RUBY
          metric "Sky is limit" do
            model Sky, :conditions=>["height > 3"]
            Sky.after_save { |sky| track! if sky.height_changed? && sky.height > 3 }
          end
        RUBY
      end
      Vanity.playground.metrics
      times = 0
      metric(:sky_is_limit).hook do
        times += 1
      end
      Sky.create!
      (1..5).each do |height|
        Sky.last.update_attributes! :height=>height
      end
      assert_equal 2, times
    end

    test "do it youself" do
      File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
        f.write <<-RUBY
          metric "Sky is limit" do
            Sky.after_save { |sky| track! if sky.height_changed? && sky.height > 3 }
          end
        RUBY
      end
      Vanity.playground.metrics
      (1..5).each do |height|
        Sky.create! :height=>height
      end
      Sky.first.update_attributes! :height=>4
      assert_equal 3, Vanity::Metric.data(metric(:sky_is_limit)).last.last
    end

  end

  # -- Google Analytics --
  
  context "Google Analytics" do

    setup do
      File.open "tmp/experiments/metrics/ga.rb", "w" do |f|
        f.write <<-RUBY
          metric "GA" do
            google_analytics "UA2"
          end
        RUBY
      end
    end

    GA_RESULT = Struct.new(:date, :pageviews, :visits)
    GA_PROFILE = Struct.new(:web_property_id)

    test "fail if Garb not available" do
      File.open "tmp/experiments/metrics/ga.rb", "w" do |f|
        f.write <<-RUBY
          metric "GA" do
            expects(:require).raises LoadError
            google_analytics "UA2"
          end
        RUBY
      end
      assert_raise LoadError do
        Vanity.playground.metrics
      end
    end

    test "constructs a report" do
      Vanity.playground.metrics
      assert metric(:ga).report
    end

    test "default to pageviews metric" do
      Vanity.playground.metrics
      assert_equal [:pageviews], metric(:ga).report.metrics.elements
    end

    test "apply data dimension and sort" do
      Vanity.playground.metrics
      assert_equal [:date], metric(:ga).report.dimensions.elements
      assert_equal [:date], metric(:ga).report.sort.elements
    end

    test "accept other metrics" do
      File.open "tmp/experiments/metrics/ga.rb", "w" do |f|
        f.write <<-RUBY
          metric "GA" do
            google_analytics "UA2", :visitors
          end
        RUBY
      end
      Vanity.playground.metrics
      assert_equal [:visitors], metric(:ga).report.metrics.elements
    end

    test "does not support hooks" do
      Vanity.playground.metrics
      assert_raises RuntimeError do
        metric(:ga).hook
      end
    end

    test "should find matching profile" do
      Vanity.playground.metrics
      Garb::Profile.expects(:all).returns(Array.new(3) { |i| GA_PROFILE.new("UA#{i + 1}") })
      metric(:ga).report.stubs(:send_request_for_body).returns(nil)
      Garb::ReportResponse.stubs(:new).returns(mock(:results=>[]))
      metric(:ga).values(Date.parse("2010-02-10"), Date.parse("2010-02-12"))
      assert_equal "UA2", metric(:ga).report.profile.web_property_id
    end

    test "should map results from report" do
      Vanity.playground.metrics
      today = Date.today
      response = mock(:results=>Array.new(3) { |i| GA_RESULT.new("2010021#{i}", i + 1) })
      Garb::Profile.stubs(:all).returns([])
      Garb::ReportResponse.expects(:new).returns(response)
      metric(:ga).report.stubs(:send_request_for_body).returns(nil)
      assert_equal [1,2,3], metric(:ga).values(Date.parse("2010-02-10"), Date.parse("2010-02-12"))
    end

    test "mapping GA metrics to single value" do
      File.open "tmp/experiments/metrics/ga.rb", "w" do |f|
        f.write <<-RUBY
          metric "GA" do
            google_analytics "UA2", :mapper=>lambda { |e| e.pageviews * e.visits }
          end
        RUBY
      end
      Vanity.playground.metrics
      today = Date.today
      response = mock(:results=>Array.new(3) { |i| GA_RESULT.new("2010021#{i}", i + 1, i + 1) })
      Garb::Profile.stubs(:all).returns([])
      Garb::ReportResponse.expects(:new).returns(response)
      metric(:ga).report.stubs(:send_request_for_body).returns(nil)
      assert_equal [1,4,9], metric(:ga).values(Date.parse("2010-02-10"), Date.parse("2010-02-12"))
    end

  end
  

  # -- Helper methods --

  def today
    @today ||= Date.today
  end

  teardown do
    Sky.delete_all
    Sky.after_create.clear
    Sky.after_save.clear
  end

end
