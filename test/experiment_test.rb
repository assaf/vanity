require "test/test_helper"

class ExperimentTest < MiniTest::Unit::TestCase
  def test_experiment_mapping_name_to_id
    experiment = Vanity.playground.define("Green Button/Alert", :ab_test) { }
    assert_equal "Green Button/Alert", experiment.name
    assert_equal :green_button_alert, experiment.id
  end

  def test_saving_experiment_after_definition
    Vanity.playground.define :simple, :ab_test do
      expects(:save)
    end
  end

  def test_experiment_has_created_timestamp
    Vanity.playground.define(:simple, :ab_test) {}
    assert_instance_of Time, experiment(:simple).created_at
    assert_in_delta experiment(:simple).created_at.to_i, Time.now.to_i, 1
  end
 
  def test_experiment_keeps_created_timestamp_across_definitions
    early, late = Time.now - 1.day, Time.now
    Time.expects(:now).once.returns(early)
    Vanity.playground.define(:simple, :ab_test) {}
    assert_equal early.to_i, experiment(:simple).created_at.to_i

    new_playground
    Time.expects(:now).once.returns(late)
    Vanity.playground.define(:simple, :ab_test) {}
    assert_equal early.to_i, experiment(:simple).created_at.to_i
  end

  def test_experiment_has_description
    Vanity.playground.define :simple, :ab_test do
      description "Simple experiment"
    end
    assert_equal "Simple experiment", experiment(:simple).description
  end

end
