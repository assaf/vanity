require "test/test_helper"

class AbTestTest < MiniTest::Spec
  it "uses A/B test when type: :ab_test" do
    experiment(:ab, type: :ab_test) { }
    assert_instance_of Vanity::Experiment::AbTest, experiment(:ab)
  end

  it "uses A/B as default test type" do
    experiment(:default) { }
    assert_instance_of Vanity::Experiment::AbTest, experiment(:default)
  end

  it "requires at least two alternatives per experiment" do
    assert_raises RuntimeError do
      experiment :none, type: :ab_test do
        alternatives []
      end
    end
    assert_raises RuntimeError do
      experiment :one, type: :ab_test do
        alternatives "foo"
      end
    end
    experiment :two, type: :ab_test do
      alternatives "foo", "bar"
    end
  end

  it "returns the same alternative consistently" do
    experiment :foobar do
      alternatives "foo", "bar"
      identify { "6e98ec" }
    end
    assert value = experiment(:foobar).choose
    assert_match /foo|bar/, value
    1000.times do
      assert_equal value, experiment(:foobar).choose
    end
  end

  it "returns different alternatives for each participant" do
    experiment :foobar do
      alternatives "foo", "bar"
      identify { rand(1000).to_s }
    end
    alts = Array.new(1000) { experiment(:foobar).choose }
    assert_equal %w{bar foo}, alts.uniq.sort
    assert_in_delta alts.select { |a| a == "foo" }.count, 500, 50
  end

  it "records all participants in each alternative" do
    experiment :foobar do
      alternatives "foo", "bar"
      identify { rand(200).to_s }
    end
    1000.times { experiment(:foobar).choose }
    totals = experiment(:foobar).measure
    assert_equal 200, totals.inject(0) { |a,(k,v)| a + v[:participants] }
    assert_in_delta totals["foo"][:participants], 100, 20
  end

  it "records conversion only once for each participant" do
    test = self
    experiment :foobar do
      alternatives "foo", "bar"
      identify { test.identity ||= rand(100).to_s }
    end
    1000.times do
      test.identity = nil
      experiment(:foobar).choose
      experiment(:foobar).conversion!
    end
    totals = experiment(:foobar).measure
    assert_equal 100, totals.inject(0) { |a,(k,v)| a + v[:conversions] }
  end

  it "records conversion only for participants" do
    test = self
    experiment :foobar do
      alternatives "foo", "bar"
      identify { test.identity ||= rand(100).to_s }
    end
    1000.times do
      test.identity = nil
      experiment(:foobar).choose
      experiment(:foobar).conversion!
      test.identity << "!"
      experiment(:foobar).conversion!
    end
    totals = experiment(:foobar).measure
    assert_equal 100, totals.inject(0) { |a,(k,v)| a + v[:conversions] }
  end
end
