require "minitest/spec"
require "mocha"
require "lib/vanity"
MiniTest::Unit.autorun

class MiniTest::Spec
  def namespace
    "vanity_0"
  end

  def experiment(name, options = nil, &block)
    if block
      Vanity.playground.define name, options, &block
    else
      Vanity.playground.experiment(name)
    end
  end

  def nuke_playground
    Vanity.playground.redis.flushdb
    new_playground
    Vanity.identity = nil
  end

  def new_playground
    Vanity.instance_variable_set :@playground, Vanity::Playground.new
  end
end
