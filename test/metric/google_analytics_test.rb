require "test_helper"

describe "Google Analytics" do
  before do
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

  it "fail if Garb not available" do
    File.open "tmp/experiments/metrics/ga.rb", "w" do |f|
      f.write <<-RUBY
        metric "GA" do
          expects(:require).raises LoadError
          google_analytics "UA2"
        end
      RUBY
    end
    assert_raises LoadError do
      Vanity.playground.metrics
    end
  end

  it "constructs a report" do
    Vanity.playground.metrics
    assert metric(:ga).report
  end

  it "default to pageviews metric" do
    Vanity.playground.metrics
    assert_equal [:pageviews], metric(:ga).report.metrics.elements
  end

  it "apply data dimension and sort" do
    Vanity.playground.metrics
    assert_equal [:date], metric(:ga).report.dimensions.elements
    assert_equal [:date], metric(:ga).report.sort.elements
  end

  it "accept other metrics" do
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

  it "does not support hooks" do
    Vanity.playground.metrics
    assert_raises RuntimeError do
      metric(:ga).hook
    end
  end

  it "should find matching profile" do
    Vanity.playground.metrics
    Garb::Profile.expects(:all).returns(Array.new(3) { |i| GA_PROFILE.new("UA#{i + 1}") })
    metric(:ga).report.stubs(:send_request_for_body).returns(nil)
    Garb::ReportResponse.stubs(:new).returns(mock(:results=>[]))
    metric(:ga).values(Date.parse("2010-02-10"), Date.parse("2010-02-12"))
    assert_equal "UA2", metric(:ga).report.profile.web_property_id
  end

  it "should map results from report" do
    Vanity.playground.metrics
    today = Date.today
    response = mock(:results=>Array.new(3) { |i| GA_RESULT.new("2010021#{i}", i + 1) })
    Garb::Profile.stubs(:all).returns([])
    Garb::ReportResponse.expects(:new).returns(response)
    metric(:ga).report.stubs(:send_request_for_body).returns(nil)
    assert_equal [1,2,3], metric(:ga).values(Date.parse("2010-02-10"), Date.parse("2010-02-12"))
  end

  it "mapping GA metrics to single value" do
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
