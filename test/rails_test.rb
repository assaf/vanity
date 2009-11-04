require "test/test_helper"

class UseVanityController < ActionController::Base
  include Vanity::Helpers

  def index
    render text: "hai"
  end

  attr_accessor :current_user
end

# Pages accessible to everyone, e.g. sign in, community search.
class UseVanityTest < ActionController::TestCase
  tests UseVanityController

  def setup
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
    assert_match /^[a-f0-9]{32}$/, cookies['vanity_id']
  end

  def test_vanity_cookie_retains_id
    @request.cookies['vanity_id'] = "from_last_time"
    get :index
    assert_equal "from_last_time", cookies['vanity_id']
  end

  def test_vanity_identity_set_from_cookie
    @request.cookies['vanity_id'] = "from_last_time"
    get :index
    assert_equal "from_last_time", Vanity.identity
  end

  def test_vanity_identity_set_from_user
    @controller.current_user = mock("user", id: "user_id")
    get :index
    assert_equal "user_id", Vanity.identity
  end

  def test_vanity_identity_with_no_user_model
    UseVanityController.class_eval do
      use_vanity nil
    end
    @controller.current_user = Object.new
    get :index
    assert_match /^[a-f0-9]{32}$/, cookies['vanity_id']
  end

  def test_use_vanity_requires_arguments
    assert_raise ArgumentError do
      UseVanityController.class_eval do
        use_vanity
      end
    end
  end

  def test_use_vanity_options_affect_filter
    UseVanityController.class_eval do
      use_vanity nil, except: [:index]
    end
    @controller.current_user = Object.new
    get :index
    assert_match /^[a-f0-9]{32}$/, cookies['vanity_id']
  end

  def teardown
    UseVanityController.send(:filter_chain).clear
    nuke_playground
  end
end


class AbTestHelpersController < ActionController::Base
  include Vanity::Helpers
  use_vanity nil

  def choose_render
    render text: ab_test(:simple_ab)
  end

  def choose_view
    render inline: "<%= ab_test(:simple_ab) %>"
  end

  def choose_capture
    render file: File.join(File.dirname(__FILE__), "ab_test_template.erb")
  end

  def goal
    ab_goal! :simple_ab
    render text: ""
  end
end

class AbTestHelpersTest < ActionController::TestCase
  tests AbTestHelpersController
  def setup
    experiment :simple_ab do
      true_false
    end
  end

  def test_fail_if_no_experiment
    new_playground
    assert_raise MissingSourceFile do
      get :choose_render
    end
  end

  def test_ab_test_chooses_in_render
    responses = Array.new(100) do
      @controller.send(:cookies).clear
      get :choose_render
      @response.body
    end
    assert_equal %w{false true}, responses.uniq.sort
  end

  def test_ab_test_chooses_view_helper
    responses = Array.new(100) do
      @controller.send(:cookies).clear
      get :choose_view
      @response.body
    end
    assert_equal %w{false true}, responses.uniq.sort
  end

  def test_ab_test_with_capture
    responses = Array.new(100) do
      @controller.send(:cookies).clear
      get :choose_capture
      @response.body
    end
    assert_equal %w{false true}, responses.map(&:strip).uniq.sort
  end

  def test_ab_test_goal
    responses = Array.new(100) do
      @controller.send(:cookies).clear
      get :goal
      @response.body
    end
  end

  def teardown
    nuke_playground
  end
end
