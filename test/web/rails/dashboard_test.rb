require "test_helper"

class VanityController < ActionController::Base
  include Vanity::Rails::Dashboard
end

class RailsDashboardTest < ActionController::TestCase
  tests VanityController

  def setup
    super
    Vanity.playground.collecting = true
    metric :sugar_high
    new_ab_test :food do
      alternatives :apple, :orange
      metrics :sugar_high
      identify { '1' }
    end

    metric :liquidity
    new_ab_test :drink do
      alternatives :tea, :coffee
      metrics :liquidity
      identify { '1' }
    end
  end

  # --  Test dashboard --

  def test_index
    get :index
    assert_response :success
    assert @response.body =~ %r{div class="vanity"}
    assert @response.body =~ %r{<h2>Experiments</h2>}
    assert @response.body =~ %r{<h2>Metrics</h2>}
  end

  def test_index_not_collecting
    Vanity.playground.collecting = false
    get :index
    assert_response :success
    assert @response.body =~ %r{<div class="alert collecting">}
  end

  def test_index_not_persisted
    name = 'Price'
    id = :price
    experiment = Vanity::Experiment::AbTest.new(Vanity.playground, id, name)
    Vanity.playground.experiments[id] = experiment

    get :index
    assert_response :success
    assert @response.body =~ %r{<div class="alert persistance">}

    Vanity.playground.experiments.delete(id)
  end

  # --  Actions used in non-admin actions, e.g. in JS --

  def test_add_participant
    xhr :post, :add_participant, :v => 'food=0'
    assert_response :success
    assert @response.body.blank?
    assert_equal 1, experiment(:food).alternatives.map(&:participants).sum
  end

  def test_add_participant_multiple_experiments
    xhr :post, :add_participant, :v => 'food=0,drink=1'
    assert_response :success
    assert @response.body.blank?
    assert_equal 1, experiment(:food).alternatives.map(&:participants).sum
    assert_equal 1, experiment(:drink).alternatives.map(&:participants).sum
  end

  def test_add_participant_with_invalid_request
    @request.user_agent = 'Googlebot/2.1 ( http://www.google.com/bot.html)'
    xhr :post, :add_participant, :v => 'food=0'
    assert_equal 0, experiment(:food).alternatives.map(&:participants).sum
  end

  def test_add_participant_no_params
    xhr :post, :add_participant
    assert_response :not_found
    assert @response.body.blank?
  end

  def test_add_participant_not_fail_for_unknown_experiment
    xhr :post, :add_participant, :e => 'unknown=0'
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
    assert !Vanity.playground.experiment(:food).active?
  end

  def test_chooses
    xhr :post, :chooses, :e => "food", :a => 0
    assert_response :success
  end
end
