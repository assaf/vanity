require "test/test_helper"

class VanityController < ActionController::Base
  include Vanity::Rails::Dashboard
end

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

  # --  Actions accessible to everyone, e.g. sign in, community search --

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

  # --  Test administrator actions --

  def test_participant_renders_experiment_for_id
    experiment(:food).choose
    get :participant, :id => "1"
    assert_response :success
    assert @response.body =~ %r{id 1 is taking part in the following experiments:\n<ul class=\"experiments\">[\s]+<li class=\"experiment ab_test}
  end

  def test_participant_renders_empty_for_bad_id
    get :participant, :id => "2"
    assert_response :success
    assert @response.body =~ %r{<ul class=\"experiments\">[\s]+</ul>}
  end

  def test_participant_renders_empty_for_no_id
    get :participant
    assert_response :success
    assert @response.body =~ %r{<ul class=\"experiments\">[\s]+</ul>}
  end

  def test_complete_forces_confirmation
    xhr :post, :complete, :e => "food", :a => 0
    assert_response :success
    assert_equal 0, assigns(:to_confirm)
  end

  def test_complete_with_confirmation_completes
    xhr :post, :complete, :e => "food", :a => 0, :confirmed => 'true'
    assert_response :success
    assert !Vanity.playground.experiment('food').active?
  end

  def test_chooses
    xhr :post, :chooses, :e => "food", :a => 0
    assert_response :success
  end
end
