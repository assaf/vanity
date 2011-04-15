require "test/test_helper"

class VanityController < ActionController::Base
  include Vanity::Rails::Dashboard
end

# Pages accessible to everyone, e.g. sign in, community search.
class RailsDashboardTest < ActionController::TestCase
  tests VanityController

  def setup
    Vanity.playground.collecting = true
    new_ab_test :food do
      alternatives :apple, :orange
      identify { '1' }
    end
  end

  def test_chooses_ajax
    Vanity.playground.be_bot_resistant
    xhr :post, :chooses, :e => "food", :a => 0
    assert_response :success
    assert @response.body.blank?
  end

  def test_chooses
    post :chooses, :e => "food"
    assert_response :success
    assert !@response.body.blank?
  end
end
