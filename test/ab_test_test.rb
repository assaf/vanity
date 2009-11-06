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

  it "returns the same alternative consistently from choice" do
    experiment :foobar do
      alternatives "foo", "bar"
    end
    assert value = experiment(:foobar).choice(Vanity.identity)
    assert_match /foo|bar/, value
    1000.times do
      assert_equal value, experiment(:foobar).choice(Vanity.identity)
    end
  end

  it "returns different alternatives for each participant from choice" do
    experiment :foobar do
      alternatives "foo", "bar"
    end
    alts = Array.new(1000) { experiment(:foobar).choice(rand) }
    assert_equal %w{bar foo}, alts.uniq.sort
    assert_in_delta alts.select { |a| a == "foo" }.count, 500, 50
  end

  it "records all participants in each alternative" do
    experiment :foobar do
      alternatives "foo", "bar"
    end
    ids = Array.new(200) { rand.to_s }.uniq
    1000.times { experiment(:foobar).choice(ids[rand(ids.size)]) }
    totals = experiment(:foobar).measure
    assert_equal ids.size, totals.inject(0) { |a,(k,v)| a + v[:participants] }
    assert_in_delta totals["foo"][:participants], 100, 20
  end

  it "records conversion only once for each participant" do
    experiment :foobar do
      alternatives "foo", "bar"
    end
    ids = Array.new(100) { rand.to_s }.uniq
    1000.times do
      experiment(:foobar).choice(ids[rand(ids.size)])
      experiment(:foobar).converted ids[rand(ids.size)]
    end
    totals = experiment(:foobar).measure
    assert_equal ids.size, totals.inject(0) { |a,(k,v)| a + v[:conversions] }
  end

  it "records conversion only for participants" do
    experiment :foobar do
      alternatives "foo", "bar"
    end
    ids = Array.new(100) { rand.to_s }.uniq
    1000.times do
      experiment(:foobar).choice(ids[rand(ids.size)])
      experiment(:foobar).converted ids[rand(ids.size)]
      experiment(:foobar).converted ids[rand(ids.size)] + "!"
    end
    totals = experiment(:foobar).measure
    assert_equal ids.size, totals.inject(0) { |a,(k,v)| a + v[:conversions] }
  end
end
