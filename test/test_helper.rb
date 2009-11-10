$LOAD_PATH.delete_if { |path| path[/gems\/vanity-\d/] }
$LOAD_PATH.unshift File.expand_path("../lib", File.dirname(__FILE__))
RAILS_ROOT = File.expand_path("..")
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

  attr_accessor :identity # pass identity to/from experiment/test case

  def teardown
    nuke_playground
  end
end

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end
