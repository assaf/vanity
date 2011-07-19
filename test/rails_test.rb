require "test/test_helper"

class UseVanityController < ActionController::Base
  attr_accessor :current_user

  def index
    render :text=>ab_test(:pie_or_cake)
  end
end

# Pages accessible to everyone, e.g. sign in, community search.
class UseVanityTest < ActionController::TestCase
  tests UseVanityController

  def setup
    super
    metric :sugar_high
    new_ab_test :pie_or_cake do
      metrics :sugar_high
    end
    UseVanityController.class_eval do
      use_vanity :current_user
    end
    if ::Rails.respond_to?(:application) # Rails 3 configuration
      ::Rails.application.config.session_options[:domain] = '.foo.bar'
    end
  end

  def test_chooses_sets_alternatives_for_rails_tests
    experiment(:pie_or_cake).chooses(true)
    get :index
    assert_equal 'true', @response.body
 
    experiment(:pie_or_cake).chooses(false)
    get :index
    assert_equal 'false', @response.body
  end


  def test_vanity_cookie_is_persistent
    get :index
    assert cookie = @response["Set-Cookie"].find { |c| c[/^vanity_id=/] }
    assert expires = cookie[/vanity_id=[a-f0-9]{32}; path=\/; expires=(.*)(;|$)/, 1]
    assert_in_delta Time.parse(expires), Time.now + 1.month, 1.minute
  end

  def test_vanity_cookie_default_id
    get :index
    assert cookies['vanity_id'] =~ /^[a-f0-9]{32}$/
  end

  def test_vanity_cookie_retains_id
    @request.cookies['vanity_id'] = "from_last_time"
    get :index
    assert_equal "from_last_time", cookies['vanity_id']
  end

  def test_vanity_identity_set_from_cookie
    @request.cookies['vanity_id'] = "from_last_time"
    get :index
    assert_equal "from_last_time", @controller.send(:vanity_identity)
  end

  def test_vanity_identity_set_from_user
    @controller.current_user = mock("user", :id=>"user_id")
    get :index
    assert_equal "user_id", @controller.send(:vanity_identity)
  end

  def test_vanity_identity_with_no_user_model
    UseVanityController.class_eval do
      use_vanity nil
    end
    @controller.current_user = Object.new
    get :index
    assert cookies['vanity_id'] =~ /^[a-f0-9]{32}$/
  end

  def test_vanity_identity_set_with_block
    UseVanityController.class_eval do
      attr_accessor :project_id
      use_vanity { |controller| controller.project_id }
    end
    @controller.project_id = "576"
    get :index
    assert_equal "576", @controller.send(:vanity_identity)
  end

  # query parameter filter

  def test_redirects_and_loses_vanity_query_parameter
    get :index, :foo=>"bar", :_vanity=>"567"
    assert_redirected_to "/use_vanity?foo=bar"
  end

  def test_sets_choices_from_vanity_query_parameter
    first = experiment(:pie_or_cake).alternatives.first
    fingerprint = experiment(:pie_or_cake).fingerprint(first)
    10.times do
      @controller = nil ; setup_controller_request_and_response
      get :index, :_vanity => fingerprint
      assert_equal experiment(:pie_or_cake).choose, experiment(:pie_or_cake).alternatives.first
      assert experiment(:pie_or_cake).showing?(first)
    end
  end

  def test_does_nothing_with_vanity_query_parameter_for_posts
    experiment(:pie_or_cake).chooses(experiment(:pie_or_cake).alternatives.last.value)
    first = experiment(:pie_or_cake).alternatives.first
    fingerprint = experiment(:pie_or_cake).fingerprint(first)
    post :index, :foo => "bar", :_vanity => fingerprint
    assert_response :success
    assert !experiment(:pie_or_cake).showing?(first)
  end

  def test_cookie_domain_from_rails_configuration
    get :index
    assert_equal cookies["vanity_id"][:domain], '.foo.bar' if ::Rails.respond_to?(:application)
  end

  # -- Load path --

  def test_load_path
    assert_equal File.expand_path("tmp/experiments"), load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.load_path
    RB
  end

  def test_settable_load_path
    assert_equal File.expand_path("tmp/predictions"), load_rails(<<-RB)
Vanity.playground.load_path = "predictions"
initializer.after_initialize
$stdout << Vanity.playground.load_path
    RB
  end

  def test_absolute_load_path
    assert_equal File.expand_path("/tmp/var"), load_rails(<<-RB)
Vanity.playground.load_path = "/tmp/var"
initializer.after_initialize
$stdout << Vanity.playground.load_path
    RB
  end


  # -- Connection configuration --

  def test_default_connection
    assert_equal "redis://127.0.0.1:6379/0", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.connection
    RB
  end

  def test_connection_from_string
    assert_equal "redis://192.168.1.1:6379/5", load_rails(<<-RB)
Vanity.playground.establish_connection "redis://192.168.1.1:6379/5"
initializer.after_initialize
$stdout << Vanity.playground.connection
    RB
  end

  def test_connection_from_yaml
    FileUtils.mkpath "tmp/config"
    ENV["RAILS_ENV"] = "production"
    File.open("tmp/config/vanity.yml", "w") do |io|
      io.write <<-YML
production:
  adapter: redis
  host: somehost
  database: 15
      YML
    end
    assert_equal "redis://somehost:6379/15", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.connection
    RB
  ensure
    File.unlink "tmp/config/vanity.yml"
  end

  def test_mongo_connection_from_yaml
    FileUtils.mkpath "tmp/config"
    File.open("tmp/config/vanity.yml", "w") do |io|
      io.write <<-YML
mongodb:
  adapter: mongodb
  host: localhost
  port: 27017
  database: vanity_test
      YML
    end

    ENV["RAILS_ENV"] = "mongodb"
    assert_equal "mongodb://localhost:27017/vanity_test", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.connection
    RB
  ensure
    File.unlink "tmp/config/vanity.yml"
  end

  def test_mongodb_replica_set_connection
    FileUtils.mkpath "tmp/config"
    File.open("tmp/config/vanity.yml", "w") do |io|
      io.write <<-YML
mongodb:
  adapter: mongodb
  hosts:
    - localhost
  port: 27017
  database: vanity_test
      YML
    end

    ENV["RAILS_ENV"] = "mongodb"
    assert_equal "mongodb://localhost:27017/vanity_test", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.connection
    RB

    ENV["RAILS_ENV"] = "mongodb"
    assert_equal "Mongo::ReplSetConnection", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.connection.mongo.class
    RB
  ensure
    File.unlink "tmp/config/vanity.yml"
  end

  def test_connection_from_yaml_url
    FileUtils.mkpath "tmp/config"
    ENV["RAILS_ENV"] = "production"
    File.open("tmp/config/vanity.yml", "w") do |io|
      io.write <<-YML
production: redis://somehost/15
      YML
    end
    assert_equal "redis://somehost:6379/15", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.connection
    RB
  ensure
    File.unlink "tmp/config/vanity.yml"
  end

  def test_connection_from_yaml_missing
    FileUtils.mkpath "tmp/config"
    ENV["RAILS_ENV"] = "development"
    File.open("tmp/config/vanity.yml", "w") do |io|
      io.write <<-YML
production:
  adapter: redis
      YML
    end
    assert_equal "No configuration for development", load_rails(<<-RB)
initializer.after_initialize
$stdout << (Vanity.playground.connection rescue $!.message)
    RB
  ensure
    File.unlink "tmp/config/vanity.yml"
  end

  def test_connection_from_yaml_with_erb
    FileUtils.mkpath "tmp/config"
    ENV["RAILS_ENV"] = "production"
    # Pass storage URL through environment like heroku does
    ENV["REDIS_URL"] = "redis://somehost:6379/15"
    File.open("tmp/config/vanity.yml", "w") do |io|
      io.write <<-YML
production: <%= ENV['REDIS_URL'] %>
      YML
    end
    assert_equal "redis://somehost:6379/15", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.connection
    RB
  ensure
    File.unlink "tmp/config/vanity.yml"
  end

  def test_connection_from_redis_yml
    FileUtils.mkpath "tmp/config"
    yml = File.open("tmp/config/redis.yml", "w")
    yml << "development: internal.local:6379\n"
    yml.flush
    assert_equal "redis://internal.local:6379/0", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.connection
    RB
  ensure
    File.unlink yml.path
  end
  
  def test_collection_from_vanity_yaml
    FileUtils.mkpath "tmp/config"
    ENV["RAILS_ENV"] = "development"
    File.open("tmp/config/vanity.yml", "w") do |io|
      io.write <<-YML
development:
  collecting: false
      YML
    end
    assert_equal "false", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.collecting?
    RB
  ensure
    File.unlink "tmp/config/vanity.yml"
  end

  def test_collection_true_in_production_by_default
    assert_equal "true", load_rails(<<-RB, "production")
initializer.after_initialize
$stdout << Vanity.playground.collecting?
    RB
  end

  def test_collection_false_in_production_when_configured
    assert_equal "false", load_rails(<<-RB, "production")
Vanity.playground.collecting = false
initializer.after_initialize
$stdout << Vanity.playground.collecting?
    RB
  end

  def test_collection_false_in_development_by_default
    assert_equal "false", load_rails(<<-RB, "development")
initializer.after_initialize
$stdout << Vanity.playground.collecting?
    RB
  end

  def test_collection_true_in_development_when_configured
    assert_equal "true", load_rails(<<-RB, "development")
Vanity.playground.collecting = true
initializer.after_initialize
$stdout << Vanity.playground.collecting?
    RB
  end

  def test_collection_false_after_test!
    assert_equal "false", load_rails(<<-RB, "production")
initializer.after_initialize
Vanity.playground.test!
$stdout << Vanity.playground.collecting?
    RB
  end

  def load_rails(code, env = "production")
    tmp = Tempfile.open("test.rb")
    tmp.write <<-RB
$:.delete_if { |path| path[/gems\\/vanity-\\d/] }
$:.unshift File.expand_path("../lib")
RAILS_ROOT = File.expand_path(".")
RAILS_ENV = "#{env}"
require "initializer"
require "active_support"
Rails.configuration = Rails::Configuration.new
initializer = Rails::Initializer.new(Rails.configuration)
initializer.check_gem_dependencies
require "vanity"
    RB
    tmp.write code
    tmp.flush
    Dir.chdir "tmp" do
      open("|ruby #{tmp.path}").read
    end
  rescue
    tmp.close!
  end


  def teardown
    super
    UseVanityController.send(:filter_chain).clear
  end
end
