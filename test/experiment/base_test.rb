require "test_helper"

describe Vanity::Experiment::Base do
  before do
    metric "Happiness"
  end

  # -- Defining experiment --

  it "can access experiment by id" do
    exp = new_ab_test(:ice_cream_flavor) do
      metrics :happiness
      default false
    end
    assert_equal exp, experiment(:ice_cream_flavor)
  end

  it "fails when defining same experiment twice" do
    File.write("tmp/experiments/ice_cream_flavor.rb", <<-RUBY)
        ab_test "Ice Cream Flavor" do
          default false
        end
        ab_test "Ice Cream Flavor" do
          default false
        end
    RUBY
    Vanity.unload!
    assert_raises NameError do
      experiment(:ice_cream_flavor)
    end
  end

  # -- Loading experiments --

  it "fails if cannot load named experiment" do
    assert_raises Vanity::NoExperimentError do
      experiment(:ice_cream_flavor)
    end
  end

  it "loads the experiment" do
    File.write("tmp/experiments/ice_cream_flavor.rb", <<-RUBY)
        ab_test "Ice Cream Flavor" do
          def xmts
            "x"
          end
          default false
        end
    RUBY
    Vanity.unload!
    assert_equal "x", experiment(:ice_cream_flavor).xmts
  end

  it "fails if error loading experiment" do
    File.write("tmp/experiments/ice_cream_flavor.rb", "fail 'yawn!'")
    Vanity.unload!
    assert_raises NameError do
      experiment(:ice_cream_flavor)
    end
  end

  it "complains if not defined where expected" do
    File.write("tmp/experiments/ice_cream_flavor.rb", "")
    Vanity.unload!
    assert_raises NameError do
      experiment(:ice_cream_flavor)
    end
  end

  it "reloading experiments" do
    new_ab_test(:ab) do
      metrics :happiness
      default false
    end
    new_ab_test(:cd) do
      metrics :happiness
      default false
    end
    assert_equal 2, Vanity.playground.experiments.size
    Vanity.playground.reload!
    assert Vanity.playground.experiments.empty?
  end

  # -- Attributes --

  it "maps the experiment name to id" do
    experiment = new_ab_test("Ice Cream Flavor/Tastes") do
      metrics :happiness
      default false
    end
    assert_equal "Ice Cream Flavor/Tastes", experiment.name
    assert_equal :ice_cream_flavor_tastes, experiment.id
  end

  it "saves the experiment after definition" do
    File.write("tmp/experiments/ice_cream_flavor.rb", <<-RUBY)
        ab_test "Ice Cream Flavor" do
          default false
        end
    RUBY
    Vanity.unload!
    metric :happiness
    Vanity.playground.experiment(:ice_cream_flavor)
  end

  it "has created timestamp" do
    new_ab_test(:ice_cream_flavor) do
      metrics :happiness
      default false
    end
    assert_kind_of Time, experiment(:ice_cream_flavor).created_at
    assert_in_delta experiment(:ice_cream_flavor).created_at.to_i, Time.now.to_i, 1
  end

  it "keeps created timestamp across definitions" do
    past = Date.today - 1
    Timecop.freeze past.to_time do
      new_ab_test(:ice_cream_flavor) do
        metrics :happiness
        default false
      end
    end

    vanity_reset
    metric :happiness
    new_ab_test(:ice_cream_flavor) do
      metrics :happiness
      default false
    end
    assert_equal past.to_time.to_i, experiment(:ice_cream_flavor).created_at.to_i
  end

  it "has a description" do
    new_ab_test :ice_cream_flavor do
      description "Because 31 is not enough ..."
      metrics :happiness
      default false
    end
    assert_equal "Because 31 is not enough ...", experiment(:ice_cream_flavor).description
  end

  it "stores nothing when collection disabled" do
    not_collecting!
    new_ab_test(:ice_cream_flavor) do
      metrics :happiness
      default false
    end
    experiment(:ice_cream_flavor).complete!
  end

  # -- completion -- #

  # check_completion is called by derived classes, but since it's
  # part of the base_test I'm testing it here.
  it "handles error in check completion" do
    new_ab_test(:ab) do
      metrics :happiness
      default false
    end
    e = experiment(:ab)
    e.complete_if { true }
    e.stubs(:complete!).raises(RuntimeError, "A forced error")
    Vanity.logger.expects(:warn)
    e.stubs(:identity).returns(:b)
    e.track!(:a, Time.now, 10)
  end

  it "complete updates completed_at" do
    new_ab_test(:ice_cream_flavor) do
      metrics :happiness
      default false
    end

    time = Time.utc(2008, 9, 1, 12, 0, 0)
    Timecop.freeze(time) do
      experiment(:ice_cream_flavor).complete!(1)
    end
    assert_equal time, experiment(:ice_cream_flavor).completed_at
  end
end
