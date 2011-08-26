Dir.chdir File.expand_path(File.dirname(__FILE__) + "/..")
require "bundler"
Bundler.setup :default, :test

$:.unshift File.dirname(__FILE__) + "/../lib/"
ENV["RACK_ENV"] = "test"
ENV["DB"] ||= "redis"

require "minitest/autorun"
require "minitest/unit"
require "mocha"
require "phusion_passenger/events"
require "vanity"
require "timecop"
require "webmock/test_unit"


if $VERBOSE
  $logger = Logger.new(STDOUT)
  $logger.level = Logger::DEBUG
end


# Setup and initialize rails application (MyApp::Application).
require File.dirname(__FILE__) + "/myapp/config/application"
require "rails/test_help"


class Test::Unit::TestCase
  include WebMock::API

  # We go destructive on the database at the end of each run, so make sure we
  # don't use databases you care about. For Redis, we pick database 15
  # (default is 0).
  DATABASE = {
    "redis"=>"redis://localhost/15",
    "mongodb"=>"mongodb://localhost/vanity",
    "mysql"=> { "adapter"=>"active_record", "active_record_adapter"=>"mysql", "database"=>"vanity_test" },
    "postgres"=> { "adapter"=>"active_record", "active_record_adapter"=>"postgresql", "database"=>"vanity_test", "username"=>"postgres" },
    "mock"=>"mock:/"
  }[ENV["DB"]] or raise "No support yet for #{ENV["DB"]}"


  def setup
    FileUtils.mkpath "tmp/experiments/metrics"
    new_playground
  end

  # Call this on teardown. It wipes put the playground and any state held in it
  # (mostly experiments), resets vanity ID, and clears database of all experiments.
  def nuke_playground
    Vanity.playground.connection.flushdb
    new_playground
  end

  # Call this if you need a new playground, e.g. to re-define the same experiment,
  # or reload an experiment (saved by the previous playground).
  def new_playground
    Vanity.playground = Vanity::Playground.new(:logger=>$logger, :load_path=>"tmp/experiments")
    Vanity.playground.establish_connection DATABASE
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

  def today
    @today ||= Date.today
  end

  def not_collecting!
    Vanity.playground.collecting = false
    Vanity.playground.stubs(:connection).returns(stub(:flushdb=>nil))
  end

  def teardown
    Vanity.context = nil
    FileUtils.rm_rf "tmp"
    Vanity.playground.connection.flushdb if Vanity.playground.connected?
    WebMock.reset!
  end

  def app
    ::Rails.application
  end

end


if ENV["DB"] == "mysql" || ENV["DB"] == "postgres"
  require "generators/templates/vanity_migration"
  VanityMigration.down rescue nil
  VanityMigration.up
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
    def self.setup(&block) define_method(:setup) { super() ; instance_eval &block } end
    def self.teardown(&block) define_method(:teardown) { super() ; instance_eval &block } end
  end
  parent.const_set name.split(/\W+/).map(&:capitalize).join, klass
  klass.class_eval &block
end


# Growl notification when done running tests.
MiniTest::Unit.after_tests do
  runner = MiniTest::Unit.runner
  if runner.failures + runner.errors > 0
    message = "FAILED! #{runner.test_count} tests, #{runner.assertion_count} assertions, #{runner.failures} failures, #{runner.errors} errors, #{runner.skips} skips"
  else
    message = "Success! #{runner.test_count} tests, #{runner.assertion_count} assertions, #{runner.skips} skips"
  end
  system "growlnotify", "-m", message
end


