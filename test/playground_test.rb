require "test_helper"

describe Vanity::Playground do

  it "has one global instance" do
    assert instance = Vanity.playground
    assert_equal instance, Vanity.playground
  end

  describe "#use_js!" do
    it "sets via use_js" do
      assert !Vanity.playground.using_js?
      Vanity.playground.use_js!
      assert Vanity.playground.using_js?
    end
  end

  describe "#failover_on_datastore_error" do
    it "sets failover_on_datastore_error" do
      assert !Vanity.playground.failover_on_datastore_error?
      Vanity.playground.failover_on_datastore_error!
      assert Vanity.playground.failover_on_datastore_error?
    end
  end

  describe "#on_datastore_error" do
    it "has a default failover_on_datastore_error" do
      proc = Vanity.playground.on_datastore_error
      assert proc.respond_to?(:call)
      assert_silent do
        proc.call(Exception.new("datastore error"), self.class, caller[0][/`.*'/][1..-2], [1, 2, 3])
      end
    end
  end

  describe "#request_filter" do
    it "sets request_filter" do
      proc = Vanity.playground.request_filter
      assert proc.respond_to?(:call)
      assert_silent do
        proc.call(dummy_request)
      end
    end
  end

  describe "#add_participant_path" do
    it "sets a default add participant path" do
      assert_equal Vanity.playground.add_participant_path, Vanity::Configuration::DEFAULTS[:add_participant_route]
    end
  end

  describe "experiments_persisted?" do
    it "returns true" do
      metric "Coolness"
      new_ab_test :foobar do
        alternatives "foo", "bar"
        identify { "abcdef" }
        metrics :coolness
      end

      assert Vanity.playground.experiments_persisted?
    end

    it "returns false" do
      name = 'Price'
      id = :price
      experiment = Vanity::Experiment::AbTest.new(Vanity.playground, id, name)
      Vanity.playground.experiments[id] = experiment

      assert !Vanity.playground.experiments_persisted?

      Vanity.playground.experiments.delete(id)
    end
  end

  describe "#experiments" do
    it "saves experiments exactly once" do
      File.open "tmp/experiments/foobar.rb", "w" do |f|
        f.write <<-RUBY
          ab_test :foobar do
          end
        RUBY
      end
      Vanity::Experiment::AbTest.any_instance.expects(:save).once
      Vanity.playground.experiments
    end
  end

  describe "participant_info" do
    it "returns participant's experiments" do
      assert_equal [], Vanity.playground.participant_info("abcdef")
      metric "Coolness"
      new_ab_test :foobar do
        alternatives "foo", "bar"
        identify { "abcdef" }
        metrics :coolness
      end
      alt = experiment(:foobar).choose
      assert_equal [[Vanity.playground.experiment(:foobar), alt]], Vanity.playground.participant_info("abcdef")
    end
  end

end
