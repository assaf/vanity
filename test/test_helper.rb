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


# Time.now adapted from Jason Earl:
# http://jasonearl.com/blog/testing_time_dependent_code/index.html
def Time.now
  @active || new
end
    
# Set the time to be fake for a given block of code
def Time.is(new_time, &block)
  if block_given?
    begin
      old_time, @active = @active, new_time
      yield
    ensure
      @active = old_time
    end
  else
    @active = new_time || Time.new
  end
end
