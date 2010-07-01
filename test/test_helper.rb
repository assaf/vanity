$LOAD_PATH.delete_if { |path| path[/gems\/vanity-\d/] }
$LOAD_PATH.unshift File.expand_path("../lib", File.dirname(__FILE__))

RAILS_ROOT = File.expand_path("..")
require "test/unit"
require "mocha"
require "action_controller"
require "action_controller/test_case"
require "active_record"
require "initializer"
Rails.configuration = Rails::Configuration.new
require "phusion_passenger/events"
require "lib/vanity"
require "timecop"


if $VERBOSE
  $logger = Logger.new(STDOUT)
  $logger.level = Logger::DEBUG
end

class Test::Unit::TestCase

  def setup
    FileUtils.mkpath "tmp/experiments/metrics"
    new_playground
  end

  # Call this on teardown. It wipes put the playground and any state held in it
  # (mostly experiments), resets vanity ID, and clears database of all experiments.
  def nuke_playground
    new_playground
    Vanity.playground.connection.flushdb
  end
  # Call this if you need a new playground, e.g. to re-define the same experiment,
  # or reload an experiment (saved by the previous playground).
  def new_playground
    case ENV["ADAPTER"]
    when "redis", nil ; spec = "redis:/"
    when "mock" ; spec = "mock:/"
    else raise "No support yet for #{ENV["ADAPTER"]}"
    end
    Vanity.playground = Vanity::Playground.new(:logger=>$logger, :load_path=>"tmp/experiments")
    Vanity.playground.establish_connection spec
  end

  # Defines the specified metrics (one or more names).  Returns metric, or array
  # of metric (if more than one argument).
  def metric(*names)
    metrics = names.map do |name|
      id = name.to_s.downcase.gsub(/\W+/, '_').to_sym
      Vanity.playground.metrics[id] ||= Vanity::Metric.new(Vanity.playground, name)
    end
    names.size == 1 ? metrics.first : metrics
  end

  # Defines an A/B experiment.
  def new_ab_test(name, &block)
    id = name.to_s.downcase.gsub(/\W/, "_").to_sym
    experiment = Vanity::Experiment::AbTest.new(Vanity.playground, id, name)
    experiment.instance_eval &block
    experiment.save
    Vanity.playground.experiments[id] = experiment
  end

  # Returns named experiment.
  def experiment(name)
    Vanity.playground.experiment(name)
  end
  
  def teardown
    Vanity.context = nil
    FileUtils.rm_rf "tmp"
    Vanity.playground.connection.flushdb if Vanity.playground.connected?
  end

end

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end


ActiveRecord::Base.logger = $logger
ActiveRecord::Base.establish_connection :adapter=>"sqlite3", :database=>File.expand_path("database.sqlite")
# Call this to define aggregate functions not available in SQlite.
class ActiveRecord::Base
  def self.aggregates
    connection.raw_connection.create_aggregate("minimum", 1) do
      step do |func, value|
        func[:minimum] = value.to_i unless func[:minimum] && func[:minimum].to_i < value.to_i
      end
      finalize { |func| func.result = func[:minimum] }
    end

    connection.raw_connection.create_aggregate("maximum", 1) do
      step do |func, value|
        func[:maximum] = value.to_i unless func[:maximum] && func[:maximum].to_i > value.to_i
      end
      finalize { |func| func.result = func[:maximum] }
    end

    connection.raw_connection.create_aggregate("average", 1) do
      step do |func, value|
        func[:total] = func[:total].to_i + value.to_i
        func[:count] = func[:count].to_i + 1
      end
      finalize { |func| func.result = func[:total].to_i / func[:count].to_i }
    end
  end
end


class Array
  # Not in Ruby 1.8.6.
  unless method_defined?(:shuffle)
    def shuffle
      copy = clone
      Array.new(size) { copy.delete_at(Kernel.rand(copy.size)) } 
    end
  end
end


# Source: http://gist.github.com/25455
def context(*args, &block)
  return super unless (name = args.first) && block
  parent = Class === self ? self : (defined?(ActiveSupport::TestCase) ? ActiveSupport::TestCase : Test::Unit::TestCase)
  klass = Class.new(parent) do
    def self.test(name, &block) 
      define_method("test_#{name.gsub(/\W/,'_')}", &block) if block
    end
    def self.xtest(*args) end
    def self.setup(&block) define_method(:setup) { super() ; block.call } end
    def self.teardown(&block) define_method(:teardown) { super() ; block.call } end
  end
  parent.const_set name.split(/\W+/).map(&:capitalize).join, klass
  klass.class_eval &block
end
