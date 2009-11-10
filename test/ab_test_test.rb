require "test/test_helper"

class AbTestController < ActionController::Base
  include Vanity::Rails
  use_vanity :current_user
  attr_accessor :current_user

  def test_render
    render text: ab_test(:simple_ab)
  end

  def test_view
    render inline: "<%= ab_test(:simple_ab) %>"
  end

  def test_capture
    render file: File.join(File.dirname(__FILE__), "ab_test_template.erb")
  end

  def goal
    ab_goal! :simple_ab
    render text: ""
  end
end


class AbTestTest < ActionController::TestCase
  tests AbTestController
  def setup
    experiment(:simple_ab) { }
  end

  # Experiment definition

  def uses_ab_test_when_type_is_ab_test
    experiment(:ab, type: :ab_test) { }
    assert_instance_of Vanity::Experiment::AbTest, experiment(:ab)
  end

  def requires_at_least_two_alternatives_per_experiment
    assert_raises RuntimeError do
      experiment :none, type: :ab_test do
        alternatives []
      end
    end
    assert_raises RuntimeError do
      experiment :one, type: :ab_test do
        alternatives "foo"
      end
    end
    experiment :two, type: :ab_test do
      alternatives "foo", "bar"
    end
  end

  # Running experiment

  def returns_the_same_alternative_consistently
    experiment :foobar do
      alternatives "foo", "bar"
      identify { "6e98ec" }
    end
    assert value = experiment(:foobar).choose
    assert_match /foo|bar/, value
    1000.times do
      assert_equal value, experiment(:foobar).choose
    end
  end

  def returns_different_alternatives_for_each_participant
    experiment :foobar do
      alternatives "foo", "bar"
      identify { rand(1000).to_s }
    end
    alts = Array.new(1000) { experiment(:foobar).choose }
    assert_equal %w{bar foo}, alts.uniq.sort
    assert_in_delta alts.select { |a| a == "foo" }.count, 500, 100 # this may fail, such is propability
  end

  def records_all_participants_in_each_alternative
    ids = (Array.new(200) { |i| i.to_s } * 5).shuffle
    experiment :foobar do
      alternatives "foo", "bar"
      identify { ids.pop }
    end
    1000.times { experiment(:foobar).choose }
    totals = experiment(:foobar).measure
    assert_equal 200, totals.inject(0) { |a,(k,v)| a + v[:participants] }
    assert_in_delta totals["foo"][:participants], 100, 20
  end

  def records_each_converted_participant_only_once
    ids = (Array.new(100) { |i| i.to_s } * 5).shuffle
    test = self
    experiment :foobar do
      alternatives "foo", "bar"
      identify { test.identity ||= ids.pop }
    end
    500.times do
      test.identity = nil
      experiment(:foobar).choose
      experiment(:foobar).conversion!
    end
    totals = experiment(:foobar).measure
    assert_equal 100, totals.inject(0) { |a,(k,v)| a + v[:converted] }
  end

  def test_records_conversion_only_for_participants
    test = self
    experiment :foobar do
      alternatives "foo", "bar"
      identify { test.identity ||= rand(100).to_s }
    end
    1000.times do
      test.identity = nil
      experiment(:foobar).choose
      experiment(:foobar).conversion!
      test.identity << "!"
      experiment(:foobar).conversion!
    end
    totals = experiment(:foobar).measure
    assert_equal 100, totals.inject(0) { |a,(k,v)| a + v[:converted] }
  end


  # A/B helper methods

  def test_fail_if_no_experiment
    new_playground
    assert_raise MissingSourceFile do
      get :test_render
    end
  end

  def test_ab_test_chooses_in_render
    responses = Array.new(100) do
      @controller = nil ; setup_controller_request_and_response
      get :test_render
      @response.body
    end
    assert_equal %w{false true}, responses.uniq.sort
  end

  def test_ab_test_chooses_view_helper
    responses = Array.new(100) do
      @controller = nil ; setup_controller_request_and_response
      get :test_view
      @response.body
    end
    assert_equal %w{false true}, responses.uniq.sort
  end

  def test_ab_test_with_capture
    responses = Array.new(100) do
      @controller = nil ; setup_controller_request_and_response
      get :test_capture
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


  # Testing with tests
  
  def test_with_given_choice
    100.times do
      @controller = nil ; setup_controller_request_and_response
      experiment(:simple_ab).chooses(true)
      get :test_render
      post :goal
    end
    totals = experiment(:simple_ab).measure
    assert_equal [100,0], totals.values_at(true, false).map { |h| h[:participants] }
    assert_equal [100,0], totals.values_at(true, false).map { |h| h[:conversions] }
  end

  def test_which_chooses_non_existent_alternative
    assert_raises ArgumentError do
      experiment(:simple_ab).chooses(404)
    end
  end

end
