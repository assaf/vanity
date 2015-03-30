$LOAD_PATH.delete_if { |path| path[/gems\/vanity-\d/] }
$LOAD_PATH.unshift File.expand_path("../lib", File.dirname(__FILE__))
ENV["RACK_ENV"] = "test"
ENV["DB"] ||= "redis"

require "minitest/autorun"
require "tmpdir"
require "action_controller"
require "action_controller/test_case"
require "action_view/test_case"
require "active_record"

begin
  require "rails"
rescue LoadError
end

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require "rails/test_help"

require "vanity"
require "timecop"

if defined?(Mocha::VERSION) && Mocha::VERSION < "0.13.0"
  require "mocha"
else
  require "mocha/mini_test"
end
require "webmock/minitest"

# Due to load order differences in Rails boot and test requires we have to
# manually require these

require 'vanity/frameworks/rails'
Vanity::Rails.load!

if $VERBOSE
  $logger = Logger.new(STDOUT)
  $logger.level = Logger::DEBUG
else
  $logger = Logger.new(STDOUT)
  $logger.level = Logger::FATAL
end

module VanityTestHelpers
  # We go destructive on the database at the end of each run, so make sure we
  # don't use databases you care about. For Redis, we pick database 15
  # (default is 0).
  DATABASE = {
    "redis"=>"redis://localhost/15",
    "mongodb"=>"mongodb://localhost/vanity",
    "active_record"=> { "adapter"=>"active_record", "active_record_adapter"=>"default" },
    "mock"=>"mock:/"
  }[ENV["DB"]] or raise "No support yet for #{ENV["DB"]}"

  def setup_after
    FileUtils.mkpath "tmp/experiments/metrics"
    new_playground
  end

  def teardown_after
    Vanity.context = nil
    FileUtils.rm_rf "tmp"
    Vanity.playground.connection.flushdb if Vanity.playground.connected?
    WebMock.reset!
  end

  # Call this if you need a new playground, e.g. to re-define the same experiment,
  # or reload an experiment (saved by the previous playground).
  def new_playground
    Vanity.playground = Vanity::Playground.new(:logger=>$logger, :load_path=>"tmp/experiments")
    ActiveRecord::Base.establish_connection
    Vanity.playground.establish_connection(DATABASE)
  end

  # Defines the specified metrics (one or more names). Returns metric, or array
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

  def dummy_request
    ActionDispatch::TestRequest.new()
  end

  # Defining setup/tear down in a module and including it below doesn't
  # override the built-in setup/teardown methods, so we alias_method_chain
  # them to run.
  def self.included(klass)
    klass.class_eval {
      alias :teardown_before :teardown
      alias :teardown :teardown_after

      alias :setup_before :setup
      alias :setup :setup_after
    }
  end
end

if defined?(Test)
  class Test::Unit::TestCase
    include VanityTestHelpers
  end
end

class MiniTest::Spec
  include VanityTestHelpers
end

if defined?(MiniTest::Unit::TestCase)
  class MiniTest::Unit::TestCase
    include VanityTestHelpers
  end
end

if defined?(ActiveSupport::TestCase)
  class ActiveSupport::TestCase
    include VanityTestHelpers

    self.use_instantiated_fixtures = false if respond_to?(:use_instantiated_fixtures)
    self.use_transactional_fixtures = false if respond_to?(:use_transactional_fixtures)
  end
end

if defined?(ActionController::TestCase)
  class ActionController::TestCase
    alias :setup_controller_request_and_response_without_vanity :setup_controller_request_and_response
    # Sets Vanity.context to the current controller, so you can do things like:
    #   experiment(:simple).chooses(:green)
    def setup_controller_request_and_response
      setup_controller_request_and_response_without_vanity
      Vanity.context = @controller
    end
  end
end

if ENV["DB"] == "active_record"
  ActiveRecord::Base.establish_connection
  ActiveRecord::Base.logger = $logger

  require "generators/templates/vanity_migration"
  VanityMigration.down rescue nil
  VanityMigration.up
end
