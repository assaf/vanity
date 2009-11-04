require "test/test_helper"

class PlaygroundTest < MiniTest::Spec
  before do
    @namespace = "vanity_0"
  end

  it "has one global instance" do
    assert instance = Vanity.playground
    assert_equal instance, Vanity.playground
  end

  it "has identity value by default" do
    assert identity = Vanity.identity
    assert_equal identity, Vanity.identity
    assert_match /^[a-f0-9]{32}$/, identity
  end

  it "can accept external identity" do
    Vanity.identity = 678
    assert_equal 678, Vanity.identity
  end

  it "use vanity-{major} as default namespace" do
    assert @namespace, Vanity.playground.namespace
  end

  it "fails if it cannot load named experiment from file" do
    assert_raises MissingSourceFile do
      Vanity.playground.experiment("Green button")
    end
  end

  it "loads named experiment from experiments directory" do
    Vanity.playground.expects(:require).with("experiments/green_button")
    begin
      Vanity.playground.experiment("Green button")
    rescue LoadError=>ex
    end
  end

  it "complains if experiment not defined in expected filed" do
    Vanity.playground.expects(:require).with("experiments/green_button")
    assert_raises LoadError do
      Vanity.playground.experiment("Green button")
    end
  end

  it "returns experiment defined in file" do
    playground = class << Vanity.playground ; self ; end
    playground.send :define_method, :require do |file|
      Vanity.playground.define("Green Button") { }
    end
    assert_equal "green_button", Vanity.playground.experiment("Green button").name
  end

  it "can define and access experiment using symbol" do
    assert green = Vanity.playground.define("Green Button") { }
    assert_equal green, Vanity.playground.experiment(:green_button)
    assert red = Vanity.playground.define(:red_button) { }
    assert_equal red, Vanity.playground.experiment("Red Button")
  end

  it "detect and fail when defining the same experiment twice" do
    Vanity.playground.define("Green Button") { }
    assert_raises RuntimeError do
      Vanity.playground.define(:green_button) { }
    end
  end

  it "evalutes definition block when creating experiment" do
    Vanity.playground.define :green_button do
      expects(:xmts).returns("x")
    end
    assert_equal "x", Vanity.playground.experiment(:green_button).xmts
  end

  it "saves experiments after defining it" do
    Vanity.playground.define :green_button do
      expects(:save)
    end
  end

  it "loads experiment if one already exists" do
    Vanity.playground.define :green_button do
      @xmts = "x"
    end
    Vanity.instance_variable_set :@playground, Vanity::Playground.new
    Vanity.playground.define :green_button do
      expects(:xmts).returns(@xmts)
    end
    assert_equal "x", Vanity.playground.experiment(:green_button).xmts
  end

  it "uses playground namespace in experiment" do
    Vanity.playground.define(:green_button) {}
    assert_equal "#{@namespace}:experiments:green_button", Vanity.playground.experiment(:green_button).send(:key)
  end

  after do
    Vanity.identity = nil
    Vanity.instance_variable_set :@playground, Vanity::Playground.new
    Vanity.playground.redis.keys("#{@namespace}:*").each do |key|
      Vanity.playground.redis.del key
    end
  end
end
