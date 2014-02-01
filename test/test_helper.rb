GC.disable
$LOAD_PATH.delete_if { |path| path[/gems\/vanity-\d/] }
$LOAD_PATH.unshift File.expand_path("../lib", File.dirname(__FILE__))
ENV["RACK_ENV"] = "test"
ENV["DB"] ||= "redis"

require "test/unit"
require "tmpdir"
require "mocha"
require "action_controller"
require "action_controller/test_case"
require "action_view/test_case"
require "active_record"

begin
  require "rails"
rescue LoadError
end

if defined?(Rails::Railtie)
  require File.expand_path("../dummy/config/environment.rb",  __FILE__)
  require "rails/test_help"
else
  RAILS_ROOT = File.expand_path("..")
  require "initializer"
  require "actionmailer"
  Rails.configuration = Rails::Configuration.new

  ActionController::Routing::Routes.draw do |map|
    map.connect ':controller/:action/:id'
  end
  require "phusion_passenger/events"
end

require "lib/vanity"
require "timecop"
require "webmock/test_unit"

#Do to load order differences in Rails boot and test requires we have to manually
#require these
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
    "mongoid"=>"mongodb://localhost/vanity",
    "mysql"=> { "adapter"=>"active_record", "active_record_adapter"=>"mysql", "database"=>"vanity_test" },
    "postgres"=> { "adapter"=>"active_record", "active_record_adapter"=>"postgresql", "database"=>"vanity_test", "username"=>"postgres" },
    "mock"=>"mock:/"
  }[ENV["DB"]] or raise "No support yet for #{ENV["DB"]}"

  def rails3?
    defined?(Rails::Railtie)
  end

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
    defined?(ActionDispatch) ? ActionDispatch::TestRequest.new() : ActionController::TestRequest.new()
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

class Test::Unit::TestCase
  include WebMock::API
  include VanityTestHelpers
end

if defined?(ActiveSupport::TestCase)
  class ActiveSupport::TestCase
    include WebMock::API
    include VanityTestHelpers
  end
end

if defined?(ActionController::TestCase)
  module ActionController
    class TestCase
      alias :setup_controller_request_and_response_without_vanity :setup_controller_request_and_response
      # Sets Vanity.context to the current controller, so you can do things like:
      #   experiment(:simple).chooses(:green)
      def setup_controller_request_and_response
        setup_controller_request_and_response_without_vanity
        Vanity.context = @controller
      end
    end
  end
end

if ENV["DB"] == "postgres"
  ActiveRecord::Base.establish_connection :adapter=>"postgresql", :database=>"vanity_test"
elsif ENV["DB"] == "mysql"
  ActiveRecord::Base.establish_connection :adapter=>"mysql", :database=>"vanity_test"
end
ActiveRecord::Base.logger = $logger

if ENV["DB"] == "mysql" || ENV["DB"] == "postgres"
  require "generators/templates/vanity_migration"
  VanityMigration.down rescue nil
  VanityMigration.up
end

# test/spec/mini v3
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
