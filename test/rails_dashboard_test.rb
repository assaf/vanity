require "test/test_helper"

class VanityController < ActionController::Base
  include Vanity::Rails::Dashboard
end

# Pages accessible to everyone, e.g. sign in, community search.
class RailsDashboardTest < ActionController::TestCase
  tests VanityController

  def setup
    Vanity.playground.collecting = true
    metric :sugar_high
    new_ab_test :food do
      alternatives :apple, :orange
      metrics :sugar_high
      identify { '1' }
    end
  end

  def test_add_participant
    xhr :post, :add_participant, :e => "food", :a => 0
    assert_response :success
    assert @response.body.blank?
  end

  def test_add_participant_no_params
    xhr :post, :add_participant
    assert_response :not_found
    assert @response.body.blank?
  end

  def test_chooses
    xhr :post, :chooses, :e => "food", :a => 0
    assert_response :success
  end
  
  def test_disable
    experiment(:food).set_enabled(true)
    xhr :post, :disable, :e => "food", :a => 0
    assert_response :success
    assert !experiment(:food).enabled?
  end
  
  def test_enable
    experiment(:food).set_enabled(false)
    xhr :post, :enable, :e => "food", :a => 0
    assert_response :success
    assert experiment(:food).enabled?
  end

  def test_reset
    xhr :post, :reset, :e => "food"
    assert_response :success
  end
end
