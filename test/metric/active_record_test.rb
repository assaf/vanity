require "test_helper"

class Sky < ActiveRecord::Base
  scope :high, lambda { where("height >= 4") }
end

if ENV["DB"] == "active_record"

describe Vanity::Metric::ActiveRecord do

  before do
    Sky.connection.create_table(:skies) do |t|
      t.integer :height
      t.timestamps
    end
  end

  after do
    Sky.connection.drop_table(:skies) if Sky.connection.table_exists?(Sky.table_name)
    Sky.reset_callbacks(:create)
    Sky.reset_callbacks(:save)
  end

  it "record count" do
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

  it "record sum" do
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

  it "record average" do
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky, :average=>:height
        end
      RUBY
    end
    Vanity.playground.metrics
    Sky.create! :height=>8
    Sky.create! :height=>2
    assert_equal 5, Vanity::Metric.data(metric(:sky_is_limit)).last.last
  end

  it "record minimum" do
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

  it "record maximum" do
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

  it "with conditions" do
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

  it "with scope" do
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

  it "with timestamp" do
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky, :timestamp => :created_at
        end
      RUBY
    end
    Vanity.playground.metrics
    Sky.create!
    assert_equal 1, Sky.count
    assert_equal 1, Vanity::Metric.data(metric(:sky_is_limit)).last.last
  end

  it "with timestamp and table" do
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky, :timestamp => 'skies.created_at'
        end
      RUBY
    end
    Vanity.playground.metrics
    Sky.create!
    assert_equal 1, Sky.count
    assert_equal 1, Vanity::Metric.data(metric(:sky_is_limit)).last.last
  end

  it "hooks" do
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

  it "no hooks when metrics disabled" do
    not_collecting!
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
      total += count
    end
    Sky.create! :height=>4
    assert_equal 0, total
  end

  it "after_create not after_save" do
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

  it "with after_save" do
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky, :conditions=>["height > 3"]
          Sky.after_save { |sky| track!(:sky_is_limit) if sky.height_changed? && sky.height > 3 }
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

  it "do it yourself" do
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          Sky.after_save { |sky| track!(:sky_is_limit) if sky.height_changed? && sky.height > 3 }
        end
      RUBY
    end
    Vanity.playground.metrics
    Sky.create!
    (1..5).each do |height|
      Sky.create! :height=>height
    end
    Sky.first.update_attributes! :height=>4
    assert_equal 3, Vanity::Metric.data(metric(:sky_is_limit)).last.last
  end

  it "last update for new metric" do
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky
        end
      RUBY
    end
    assert_nil metric(:sky_is_limit).last_update_at
  end

  it "last update with records" do
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model Sky
        end
      RUBY
    end
    Sky.create! :height=>1
    Timecop.freeze Time.now + 1.day do
      Sky.create! :height=>1
    end
    assert_in_delta metric(:sky_is_limit).last_update_at.to_i, (Time.now + 1.day).to_i, 1
  end

  it "metric is specifiable with a string" do
    File.open "tmp/experiments/metrics/sky_is_limit.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sky is limit" do
          model 'Sky'
        end
      RUBY
    end
    Vanity.playground.metrics
    Sky.create!
    assert_equal 1, Vanity::Metric.data(metric(:sky_is_limit)).last.last
  end

end

end
