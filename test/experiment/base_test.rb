require "test/test_helper"

class ExperimentTest < Test::Unit::TestCase

  def setup
    super
    metric "Happiness"
  end

  # -- Defining experiment --
  
  def test_can_access_experiment_by_id
    exp = new_ab_test(:ice_cream_flavor) { metrics :happiness }
    assert_equal exp, experiment(:ice_cream_flavor)
  end

  def test_fail_when_defining_same_experiment_twice
    File.open "tmp/experiments/ice_cream_flavor.rb", "w" do |f|
      f.write <<-RUBY
        ab_test "Ice Cream Flavor" do
          metrics :happiness
        end
        ab_test "Ice Cream Flavor" do
          metrics :happiness
        end
      RUBY
    end
    assert_raises NameError do
      experiment(:ice_cream_flavor)
    end
  end


  # -- Loading experiments --

  def test_fails_if_cannot_load_named_experiment
    assert_raises Vanity::NoExperimentError do
      experiment(:ice_cream_flavor)
    end
  end

  def test_loading_experiment
    File.open "tmp/experiments/ice_cream_flavor.rb", "w" do |f|
      f.write <<-RUBY
        ab_test "Ice Cream Flavor" do
          def xmts
            "x"
          end
          metrics :happiness
        end
      RUBY
    end
    assert_equal "x", experiment(:ice_cream_flavor).xmts
  end

  def test_fails_if_error_loading_experiment
    File.open "tmp/experiments/ice_cream_flavor.rb", "w" do |f|
      f.write "fail 'yawn!'"
    end
    assert_raises NameError do
      experiment(:ice_cream_flavor)
    end
  end

  def test_complains_if_not_defined_where_expected
    File.open "tmp/experiments/ice_cream_flavor.rb", "w" do |f|
      f.write ""
    end
    assert_raises NameError do
      experiment(:ice_cream_flavor)
    end
  end

  def test_reloading_experiments
    new_ab_test(:ab) { metrics :happiness }
    new_ab_test(:cd) { metrics :happiness }
    assert_equal 2, Vanity.playground.experiments.size
    Vanity.playground.reload!
    assert Vanity.playground.experiments.empty?
  end


  # -- Attributes --

  def test_experiment_mapping_name_to_id
    experiment = new_ab_test("Ice Cream Flavor/Tastes") { metrics :happiness }
    assert_equal "Ice Cream Flavor/Tastes", experiment.name
    assert_equal :ice_cream_flavor_tastes, experiment.id
  end

  def test_saving_experiment_after_definition
    File.open "tmp/experiments/ice_cream_flavor.rb", "w" do |f|
      f.write <<-RUBY
        ab_test "Ice Cream Flavor" do
          metrics :happiness
          expects(:save).at_least_once
        end
      RUBY
    end
    Vanity.playground.experiment(:ice_cream_flavor)
  end

  def test_experiment_has_created_timestamp
    new_ab_test(:ice_cream_flavor) { metrics :happiness }
    assert_kind_of Time, experiment(:ice_cream_flavor).created_at
    assert_in_delta experiment(:ice_cream_flavor).created_at.to_i, Time.now.to_i, 1
  end
 
  def test_experiment_keeps_created_timestamp_across_definitions
    past = Date.today - 1
    Timecop.freeze past do
      new_ab_test(:ice_cream_flavor) { metrics :happiness }
      assert_equal past.to_time.to_i, experiment(:ice_cream_flavor).created_at.to_i
    end

    new_playground
    metric :happiness
    new_ab_test(:ice_cream_flavor) { metrics :happiness }
    assert_equal past.to_time.to_i, experiment(:ice_cream_flavor).created_at.to_i
  end

  def test_experiment_has_description
    new_ab_test :ice_cream_flavor do
      description "Because 31 is not enough ..."
      metrics :happiness
    end
    assert_equal "Because 31 is not enough ...", experiment(:ice_cream_flavor).description
  end

  def test_experiment_stores_nothing_when_collection_disabled
    not_collecting!
    new_ab_test(:ice_cream_flavor) { metrics :happiness }
    experiment(:ice_cream_flavor).complete!
  end

  def test_experiment_has_default
    new_ab_test :ice_cream_flavor do
      alternatives :a, :b, :c
      default :b
    end
    exp = experiment(:ice_cream_flavor)
    assert_equal exp.default, exp.alternative(:b)
  end
  
  def test_experiment_sets_default_default
    new_ab_test :ice_cream_flavor do
      alternatives :a, :b, :c
      # no default specified
    end
    exp = experiment(:ice_cream_flavor)
    assert_equal exp.default, exp.alternative(:a)
  end
  
  def test_experiment_overrides_unknown_default
    new_ab_test :ice_cream_flavor do
      alternatives :a, :b, :c
      default :badname
    end
    exp = experiment(:ice_cream_flavor)
    assert_equal exp.default, exp.alternative(:a)
  end

  def test_experiment_can_only_set_default_once
    assert_raise ArgumentError do
      new_ab_test :ice_cream_flavor do
        alternative :a, :b, :c
        default :a
        default :b
      end
    end
  end
  
  def test_experiment_can_only_have_one_default
    assert_raise ArgumentError do
      new_ab_test :ice_cream_flavor do
        alternative :a, :b, :c
        default :a, :b
      end
    end
  end
  
  def test_experiment_cannot_get_default_before_specified
    assert_raise ArgumentError do
      new_ab_test :ice_cream_flavor do
        alternative :a, :b, :c
        default
      end
    end
  end
  
  def test_experiment_accepts_nil_default
    new_ab_test :nil_default do
      alternatives nil, 'foo'
      default nil
    end
    exp = experiment(:nil_default)
    assert_equal exp.default, exp.alternative(nil)
  end
  
  def test_experiment_chooses_nil_default_default
    new_ab_test :nil_default_default do
      alternatives nil, 'foo'
      # no default specified
    end
    exp = experiment(:nil_default_default)
    assert_equal exp.default, exp.alternative(nil)
  end
  
  # -- completion -- #
  
  # check_completion is called by derived classes, but since it's
  # part of the base_test I'm testing it here.
  def test_error_in_check_completion
    new_ab_test(:ab) { metrics :happiness }
    e = experiment(:ab)
    e.complete_if { true }
    e.stubs(:complete!).raises(RuntimeError, "A forced error")
    e.expects(:warn)
    e.stubs(:identity).returns(:b)
    e.track!(:a, Time.now, 10)
  end
 
end
