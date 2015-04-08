require "test_helper"

# Pages accessible to everyone, e.g. sign in, community search.
class UseVanityController < ActionController::Base
  class TestModel
    def test_method
      ab_test(:pie_or_cake)
    end
  end
  
  attr_accessor :current_user

  def index
    render :text=>ab_test(:pie_or_cake)
  end

  def js
    ab_test(:pie_or_cake)
    render :inline => "<%= vanity_js -%>"
  end
  
  def model_js
    TestModel.new.test_method
    render :inline => "<%= vanity_js -%>"
  end
end

# class UseVanityControllerTest < ActionController::TestCase
#   tests UseVanityController

#   def setup
#     super
#     new_ab_test :pie_or_cake do
#       metrics :sugar_high
#     end

#     # Class eval this instead of including in the controller to delay
#     # execution until the request exists in the context of the test
#     UseVanityController.class_eval do
#       use_vanity :current_user
#     end
#   end

#   def teardown
#     super
#   end

#   def test_bootstraps_metric
#   end
# end

class UseVanityControllerTest < ActionController::TestCase
  tests UseVanityController

  def setup
    super
    metric :sugar_high
    new_ab_test :pie_or_cake do
      metrics :sugar_high
    end

    # Class eval this instead of including in the controller to delay
    # execution until the request exists in the context of the test
    UseVanityController.class_eval do
      use_vanity :current_user
    end

    # Rails 3 configuration for cookies
    if ::Rails.respond_to?(:application)
      ::Rails.application.config.session_options[:domain] = '.foo.bar'
    end
  end

  def teardown
    super
  end

  def test_render_js_for_tests
    Vanity.playground.use_js!
    get :js
    assert_match /script.*v=pie_or_cake=.*script/m, @response.body
  end
  
  def test_render_model_js_for_tests
    Vanity.playground.use_js!
    get :model_js
    assert_match /script.*v=pie_or_cake=.*script/m, @response.body
  end

  def test_chooses_sets_alternatives_for_rails_tests
    experiment(:pie_or_cake).chooses(true)
    get :index
    assert_equal 'true', @response.body

    experiment(:pie_or_cake).chooses(false)
    get :index
    assert_equal 'false', @response.body
  end

  def test_adds_participant_to_experiment
    get :index
    assert_equal 1, experiment(:pie_or_cake).alternatives.map(&:participants).sum
  end

  def test_does_not_add_invalid_participant_to_experiment
    @request.user_agent = "Googlebot/2.1 ( http://www.google.com/bot.html)"
    get :index
    assert_equal 0, experiment(:pie_or_cake).alternatives.map(&:participants).sum
  end

  def test_vanity_cookie_is_persistent
    get :index
    cookie = @response["Set-Cookie"].to_s
    assert_match /vanity_id=[a-f0-9]{32};/, cookie
    expires = cookie[/expires=(.*)(;|$)/, 1]
    assert expires
    assert_in_delta Time.parse(expires), Time.now + 1.month, 1.day
  end

  def test_vanity_cookie_default_id
    get :index
    assert cookies["vanity_id"] =~ /^[a-f0-9]{32}$/
  end

  def test_vanity_cookie_retains_id
    @request.cookies["vanity_id"] = "from_last_time"
    get :index
    assert_equal "from_last_time",  cookies["vanity_id"]
  end

  def test_vanity_identity_set_from_cookie
    @request.cookies["vanity_id"] = "from_last_time"
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
    assert cookies["vanity_id"] =~ /^[a-f0-9]{32}$/
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

  def test_vanity_identity_set_with_identity_paramater
    get :index, :_identity => "id_from_params"
    assert_equal "id_from_params", @controller.send(:vanity_identity)
  end

  def test_vanity_identity_prefers_block_over_symbol
    UseVanityController.class_eval do
      attr_accessor :project_id
      use_vanity(:current_user) { |controller| controller.project_id }
    end
    @controller.project_id = "576"
    @controller.current_user = stub(:id=>"user_id")

    get :index
    assert_equal "576", @controller.send(:vanity_identity)
  end

    def test_vanity_identity_prefers_parameter_over_cookie
    @request.cookies['vanity_id'] = "old_id"
    get :index, :_identity => "id_from_params"
    assert_equal "id_from_params", @controller.send(:vanity_identity)
    assert cookies['vanity_id'], "id_from_params"
  end

  def test_vanity_identity_prefers_cookie_over_object
    @request.cookies['vanity_id'] = "from_last_time"
    @controller.current_user = stub(:id=>"user_id")
    get :index
    assert_equal "from_last_time", @controller.send(:vanity_identity)
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

  def test_track_param_tracks_a_metric
    get :index, :_identity => "123", :_track => "sugar_high"
    assert_equal experiment(:pie_or_cake).alternatives[0].converted, 1
  end

  def test_cookie_domain_from_rails_configuration
    get :index
    assert_match /domain=.foo.bar/, @response["Set-Cookie"] if ::Rails.respond_to?(:application)
  end

end