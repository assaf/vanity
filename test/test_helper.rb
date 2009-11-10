require "minitest/spec"
require "mocha"
require "action_controller"
require "action_controller/test_case"
require "lib/vanity/rails"
MiniTest::Unit.autorun

class MiniTest::Unit::TestCase
  # Call this on teardown. It wipes put the playground and any state held in it
  # (mostly experiments), resets vanity ID, and clears Redis of all experiments.
  def nuke_playground
    Vanity.playground.redis.flushdb
    new_playground
    self.identity = nil
  end

  # Call this if you need a new playground, e.g. to re-define the same experiment,
  # or reload an experiment (saved by the previous playground).
  def new_playground
    Vanity.instance_variable_set :@playground, Vanity::Playground.new
  end

  # Call this to define or retrieve an experiment.
  #
  # To define an experiment give it name and block (options are optional):
  #   experiment :green_button, type: :ab_test do
  #     true_false
  #   end
  #
  # To retrieve an experiment, just the name:
  #   experiment(:green_button)
  def experiment(name, options = nil, &block)
    if block
      Vanity.playground.define name, options, &block
    else
      Vanity.playground.experiment(name)
    end
  end

  attr_accessor :identity # pass identity to/from experiment/test case

  def teardown
    nuke_playground
  end
end

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end
