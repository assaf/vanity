require "test/test_helper"

class ExperimentTest < MiniTest::Spec
  it "stores when experiment created" do
    experiment(:simple) { }
    assert_instance_of Time, experiment(:simple).created_at
    assert_in_delta experiment(:simple).created_at.to_i, Time.now.to_i, 1
  end

  it "keeps creation timestamp across definitions" do
    early = Time.now - 1.day
    Time.expects(:now).once.returns(early)
    experiment(:simple) { }
    assert_equal early.to_i, experiment(:simple).created_at.to_i
    new_playground
    experiment(:simple) { }
    assert_equal early.to_i, experiment(:simple).created_at.to_i
  end

  it "has description" do
    experiment :simple do
      description "Simple experiment"
    end
    assert_equal "Simple experiment", experiment(:simple).description
  end
end
