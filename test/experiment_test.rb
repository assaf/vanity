require "test/test_helper"

class ExperimentTest < MiniTest::Spec
  it "creates ID from name" do
    exp = experiment("Green Button/Alert") { }
    assert_equal "Green Button/Alert", exp.name
    assert_equal :green_button_alert, exp.id
  end

  it "evalutes definition block at creation" do
    experiment :green_button do
      expects(:xmts).returns("x")
    end
    assert_equal "x", experiment(:green_button).xmts
  end

  it "saves experiments after defining it" do
    experiment :green_button do
      expects(:save)
    end
  end

  it "stores when experiment created" do
    experiment(:simple) { }
    assert_instance_of Time, experiment(:simple).created_at
    assert_in_delta experiment(:simple).created_at.to_i, Time.now.to_i, 1
  end

  it "keeps creation timestamp across definitions" do
    early, late = Time.now - 1.day, Time.now
    Time.expects(:now).once.returns(early)
    experiment(:simple) { }
    assert_equal early.to_i, experiment(:simple).created_at.to_i

    new_playground
    Time.expects(:now).once.returns(late)
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
