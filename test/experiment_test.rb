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

  def test_uses_playground_namespace_for_experiment
    new_ab_test(:ice_cream_flavor) { metrics :happiness }
    assert_equal "vanity:#{Vanity::Version::MAJOR}:ice_cream_flavor", experiment(:ice_cream_flavor).send(:key)
    assert_equal "vanity:#{Vanity::Version::MAJOR}:ice_cream_flavor:participants", experiment(:ice_cream_flavor).send(:key, "participants")
  end


  # -- Loading experiments --

  def test_fails_if_cannot_load_named_experiment
    assert_raises NameError do
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
    assert 2, Vanity.playground.experiments.size
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
          expects(:save)
        end
      RUBY
    end
    Vanity.playground.experiment(:ice_cream_flavor)
  end

  def test_experiment_has_created_timestamp
    new_ab_test(:ice_cream_flavor) { metrics :happiness }
    assert_instance_of Time, experiment(:ice_cream_flavor).created_at
    assert_in_delta experiment(:ice_cream_flavor).created_at.to_i, Time.now.to_i, 1
  end
 
  def test_experiment_keeps_created_timestamp_across_definitions
    past = Date.today - 1
    Timecop.travel past do
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

end
