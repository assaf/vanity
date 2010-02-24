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
    # experiment(:pie_or_cake).fingerprint(first)
    10.times do
      @controller = nil ; setup_controller_request_and_response
      get :index, :_vanity=>"aae9ff8081"
      assert !experiment(:pie_or_cake).choose
      assert experiment(:pie_or_cake).showing?(first)
    end
  end

  def test_does_nothing_with_vanity_query_parameter_for_posts
    first = experiment(:pie_or_cake).alternatives.first
    post :index, :foo=>"bar", :_vanity=>"567"
    assert_response :success
    assert !experiment(:pie_or_cake).showing?(first)
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
    assert_equal "localhost:6379", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.redis.server
    RB
  end

  def test_configured_connection
    assert_equal "127.0.0.1:6379", load_rails(<<-RB)
Vanity.playground.redis = "127.0.0.1:6379"
initializer.after_initialize
$stdout << Vanity.playground.redis.server
    RB
  end

  def test_test_connection
    assert_equal "Vanity::MockRedis", load_rails(<<-RB)
Vanity.playground.test!
initializer.after_initialize
$stdout << Vanity.playground.redis.class
    RB
  end

  def test_connection_from_yaml
    FileUtils.mkpath "tmp/config"
    yml = File.open("tmp/config/redis.yml", "w")
    yml << "production: internal.local:6379\n"
    yml.flush
    assert_equal "internal.local:6379", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.redis.server
    RB
  ensure
    File.unlink yml
  end

  def test_connection_from_yaml_missing
    FileUtils.mkpath "tmp/config"
    yml = File.open("tmp/config/redis.yml", "w")
    yml << "development: internal.local:6379\n"
    yml.flush
    assert_equal "localhost:6379", load_rails(<<-RB)
initializer.after_initialize
$stdout << Vanity.playground.redis.server
    RB
  ensure
    File.unlink yml
  end


  def load_rails(code)
    tmp = Tempfile.open("test.rb")
    tmp.write <<-RB
$:.delete_if { |path| path[/gems\\/vanity-\\d/] }
$:.unshift File.expand_path("../lib")
RAILS_ROOT = File.expand_path(".")
RAILS_ENV = "production"
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
