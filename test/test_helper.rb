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
rescue LoadError # rubocop:todo Lint/SuppressedException
end

require File.expand_path('dummy/config/environment.rb', __dir__)
require "rails/test_help"

require "vanity"
require "timecop"
require "mocha/minitest"
require "fakefs/safe"
require "webmock/minitest"

# Due to load order differences in Rails boot and test requires we have to
# manually require these

# TODO: wonder if we can load rails only for the rails tests...
require 'vanity/frameworks/rails'
Vanity::Rails.load!

if $DEBUG
  $logger = Logger.new(STDOUT) # rubocop:todo Style/GlobalVars
  $logger.level = Logger::DEBUG # rubocop:todo Style/GlobalVars
else
  $logger = Logger.new(STDOUT) # rubocop:todo Style/GlobalVars
  $logger.level = Logger::FATAL # rubocop:todo Style/GlobalVars
end

module VanityTestHelpers
  # We go destructive on the database at the end of each run, so make sure we
  # don't use databases you care about. For Redis, we pick database 15
  # (default is 0).
  DATABASE_OPTIONS = {
    "redis" => "redis://localhost/15",
    "mongodb" => "mongodb://localhost/vanity",
    "active_record" =>  { adapter: "active_record", active_record_adapter: "default" },
    "mock" => "mock:/",
  }

  DATABASE = DATABASE_OPTIONS[ENV["DB"]] or raise "No support yet for #{ENV['DB']}"

  TEST_DATA_FILES = Dir[File.expand_path('data/*', __dir__)]
  VANITY_CONFIGS = TEST_DATA_FILES.each.with_object({}) do |path, hash|
    hash[File.basename(path)] = File.read(path)
  end

  def setup_after
    FileUtils.mkpath "tmp/experiments/metrics"
    vanity_reset
  end

  def teardown_after
    Vanity.context = nil
    FileUtils.rm_rf "tmp"
    Vanity.connection.adapter.flushdb if Vanity.connection(false) && Vanity.connection.connected?
    WebMock.reset!
  end

  # Call this if you need a new playground, e.g. to re-define the same experiment,
  # or reload an experiment (saved by the previous playground).
  def vanity_reset
    Vanity.reset!
    Vanity.configuration.logger = $logger # rubocop:todo Style/GlobalVars
    Vanity.configuration.experiments_path = "tmp/experiments"

    Vanity.disconnect!
    ActiveRecord::Base.establish_connection
    Vanity.connect!(DATABASE)

    Vanity.unload!
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
    Vanity.playground = Vanity::Playground.new
    Vanity.disconnect!
    ActiveRecord::Base.establish_connection
    Vanity.connect!(DATABASE)
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
  # @param [Hash] options Options include:
  #   [Boolean] enable (default true) - Whether or not to enable this ab_test when it gets instantiated;
  # this flag is here to simply the testing of experiment features, and also to allow
  # testing of the default behavior of an experiment when it gets loaded.
  # Note that :enable => false does NOT mean to set the ab_test to false; it
  # means to not set enabled at all (the 'actual' behavior).
  def new_ab_test(name, options = {}, &block)
    enable = options.fetch(:enable, true)
    id = name.to_s.downcase.gsub(/\W/, "_").to_sym
    experiment = Vanity::Experiment::AbTest.new(Vanity.playground, id, name)
    experiment.instance_eval(&block) if block
    experiment.save
    # new experiments start off as disabled, enable them for testing
    experiment.enabled = true if enable
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
    Vanity.configuration.collecting = false
  end

  def dummy_request
    # Rails 5 compatibility
    if ActionDispatch::TestRequest.respond_to?(:create)
      ActionDispatch::TestRequest.create
    else
      ActionDispatch::TestRequest.new
    end
  end

  # Defining setup/tear down in a module and including it below doesn't
  # override the built-in setup/teardown methods, so we alias_method_chain
  # them to run.
  def self.included(klass)
    klass.class_eval do
      alias_method :teardown_before, :teardown
      alias_method :teardown, :teardown_after

      alias_method :setup_before, :setup
      alias_method :setup, :setup_after
    end
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
    self.use_transactional_tests = false if respond_to?(:use_transactional_tests)
  end
end

# Shim for pre-5.0 tests
module LegacyTestRequests
  def rails4?
    ActiveRecord::VERSION::MAJOR <= 4
  end

  def get(path, params = {}, headers = {})
    if rails4?
      process(path, 'GET', params, headers)
    else
      process(path, method: 'GET', params: params, **headers)
    end
  end

  def post(path, params = {}, headers = {})
    if rails4?
      process(path, 'POST', params, headers)
    else
      process(path, method: 'POST', params: params, **headers)
    end
  end

  def put(path, params = {}, headers = {})
    if rails4?
      process(path, 'PUT', params, headers)
    else
      process(path, method: 'PUT', params: params, **headers)
    end
  end

  def delete(path, params = {}, headers = {})
    if rails4?
      process(path, 'DELETE', params, headers)
    else
      process(path, method: 'DELETE', params: params, **headers)
    end
  end
end

if defined?(ActionController::TestCase)
  class ActionController::TestCase
    include LegacyTestRequests

    alias setup_controller_request_and_response_without_vanity setup_controller_request_and_response
    # Sets Vanity.context to the current controller, so you can do things like:
    #   experiment(:simple).chooses(:green)
    def setup_controller_request_and_response
      setup_controller_request_and_response_without_vanity
      Vanity.context = @controller
    end
  end
end

if defined?(ActionDispatch::IntegrationTest)
  class ActionDispatch::IntegrationTest # rubocop:todo Lint/EmptyClass
  end
end

if ENV["DB"] == "active_record"
  ActiveRecord::Base.establish_connection
  ActiveRecord::Base.logger = $logger # rubocop:todo Style/GlobalVars

  Vanity.connect!(VanityTestHelpers::DATABASE)

  config = Vanity::Adapters::ActiveRecordAdapter::VanityRecord.connection_config
  ActiveRecord::Tasks::DatabaseTasks.drop(config.with_indifferent_access)

  # use generator to create the migration
  require "rails/generators"
  require "generators/vanity/migration_generator"
  Rails::Generators.invoke "vanity"

  migrate_path = File.expand_path('dummy/db/migrate', __dir__)
  if defined?(ActiveRecord::MigrationContext)
    if ActiveRecord.version.release >= Gem::Version.new('6.0')
      ActiveRecord::MigrationContext.new(migrate_path, ActiveRecord::SchemaMigration).migrate
    else
      ActiveRecord::MigrationContext.new(migrate_path).migrate
    end
  else
    ActiveRecord::Migrator.migrate(migrate_path)
  end
end
