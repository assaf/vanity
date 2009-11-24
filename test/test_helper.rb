$LOAD_PATH.delete_if { |path| path[/gems\/vanity-\d/] }
$LOAD_PATH.unshift File.expand_path("../lib", File.dirname(__FILE__))
RAILS_ROOT = File.expand_path("..")
require "minitest/spec"
require "mocha"
require "action_controller"
require "action_controller/test_case"
require "initializer"
require "lib/vanity/rails"
require "test/mock_redis" # <-- load this when you don't want to use Redis
require "timecop"
MiniTest::Unit.autorun

class MiniTest::Unit::TestCase

  # Call this on teardown. It wipes put the playground and any state held in it
  # (mostly experiments), resets vanity ID, and clears Redis of all experiments.
  def nuke_playground
    Vanity.playground.redis.flushdb
    new_playground
  end

  # Call this if you need a new playground, e.g. to re-define the same experiment,
  # or reload an experiment (saved by the previous playground).
  def new_playground
    Vanity.instance_variable_set :@playground, Vanity::Playground.new
  end

  def teardown
    nuke_playground
    Vanity.context = nil
  end
end

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end
Rails.configuration = Rails::Configuration.new

# Using DB 0 for development, don't mess with it when running Vanity test suite.
Vanity::Playground::DEFAULTS[:db] = 15
