require "test/test_helper"

class AbTestController < ActionController::Base
  use_vanity :current_user
  attr_accessor :current_user

  def test_render
    render text: ab_test(:simple)
  end

  def test_view
    render inline: "<%= ab_test(:simple) %>"
  end

  def test_capture
    render inline: "<% ab_test :simple do |value| %><%= value %><% end %>"
  end

  def goal
    ab_goal! :simple
    render text: ""
  end
end


class AbTestTest < ActionController::TestCase
  tests AbTestController

  # --  Experiment definition --

  def test_requires_at_least_two_alternatives_per_experiment
    assert_raises RuntimeError do
      ab_test :none do
        alternatives []
      end
    end
    assert_raises RuntimeError do
      ab_test :one do
        alternatives "foo"
      end
    end
    ab_test :two do
      alternatives "foo", "bar"
    end
  end
  
  def test_returning_alternative_by_value
    ab_test :abcd do
      alternatives :a, :b, :c, :d
    end
    assert_equal experiment(:abcd).alternatives[1], experiment(:abcd).alternative(:b)
    assert_equal experiment(:abcd).alternatives[3], experiment(:abcd).alternative(:d)
  end

  def test_alternative_name
    ab_test :abcd do
      alternatives :a, :b
    end
    assert_equal "option A", experiment(:abcd).alternative(:a).name
    assert_equal "option B", experiment(:abcd).alternative(:b).name
  end


  # -- Running experiment --

  def test_returns_the_same_alternative_consistently
    ab_test :foobar do
      alternatives "foo", "bar"
      identify { "6e98ec" }
    end
    assert value = experiment(:foobar).choose
    assert_match /foo|bar/, value
    1000.times do
      assert_equal value, experiment(:foobar).choose
    end
  end

  def test_returns_different_alternatives_for_each_participant
    ab_test :foobar do
      alternatives "foo", "bar"
      identify { rand }
    end
    alts = Array.new(1000) { experiment(:foobar).choose }
    assert_equal %w{bar foo}, alts.uniq.sort
    assert_in_delta alts.select { |a| a == "foo" }.count, 500, 100 # this may fail, such is propability
  end

  def test_records_all_participants_in_each_alternative
    ids = (Array.new(200) { |i| i } * 5).shuffle
    ab_test :foobar do
      alternatives "foo", "bar"
      identify { ids.pop }
    end
    1000.times { experiment(:foobar).choose }
    alts = experiment(:foobar).alternatives
    assert_equal 200, alts.map(&:participants).sum
    assert_in_delta alts.first.participants, 100, 20
  end

  def test_records_each_converted_participant_only_once
    ids = ((1..100).map { |i| [i,i] } * 5).shuffle.flatten # 3,3,1,1,7,7 etc
    ab_test :foobar do
      alternatives "foo", "bar"
      identify { ids.pop }
    end
    500.times do
      experiment(:foobar).choose
      experiment(:foobar).conversion!
    end
    alts = experiment(:foobar).alternatives
    assert_equal 100, alts.map(&:converted).sum
  end

  def test_records_conversion_only_for_participants
    ids = ((1..100).map { |i| [-i,i,i] } * 5).shuffle.flatten # -3,3,3,-1,1,1,-7,7,7 etc
    ab_test :foobar do
      alternatives "foo", "bar"
      identify { ids.pop }
    end
    500.times do
      experiment(:foobar).choose
      experiment(:foobar).conversion!
      experiment(:foobar).conversion!
    end
    alts = experiment(:foobar).alternatives
    assert_equal 100, alts.map(&:converted).sum
  end

  def test_reset_experiment
    ab_test :simple do
      identify { "me" }
      complete_if { alternatives.map(&:converted).sum >= 1 }
      outcome_is { alternative(true) }
    end
    experiment(:simple).choose
    experiment(:simple).conversion!
    refute experiment(:simple).active?
    assert_equal true, experiment(:simple).outcome.value

    experiment(:simple).reset!
    assert experiment(:simple).active?
    assert_nil experiment(:simple).outcome
    assert_nil experiment(:simple).completed_at
    assert_equal 0, experiment(:simple).alternatives.map(&:participants).sum
    assert_equal 0, experiment(:simple).alternatives.map(&:conversions).sum
    assert_equal 0, experiment(:simple).alternatives.map(&:converted).sum
  end


  # -- A/B helper methods --

  def test_fail_if_no_experiment
    assert_raise LoadError do
      get :test_render
    end
  end

  def test_ab_test_chooses_in_render
    ab_test(:simple) { }
    responses = Array.new(100) do
      @controller = nil ; setup_controller_request_and_response
      get :test_render
      @response.body
    end
    assert_equal %w{false true}, responses.uniq.sort
  end

  def test_ab_test_chooses_view_helper
    ab_test(:simple) { }
    responses = Array.new(100) do
      @controller = nil ; setup_controller_request_and_response
      get :test_view
      @response.body
    end
    assert_equal %w{false true}, responses.uniq.sort
  end

  def test_ab_test_with_capture
    ab_test(:simple) { }
    responses = Array.new(100) do
      @controller = nil ; setup_controller_request_and_response
      get :test_capture
      @response.body
    end
    assert_equal %w{false true}, responses.map(&:strip).uniq.sort
  end

  def test_ab_test_goal
    ab_test(:simple) { }
    responses = Array.new(100) do
      @controller.send(:cookies).clear
      get :goal
      @response.body
    end
  end


  # -- Testing with tests --
  
  def test_with_given_choice
    ab_test(:simple) { alternatives :a, :b, :c }
    100.times do |i|
      @controller = nil ; setup_controller_request_and_response
      experiment(:simple).chooses(:b)
      get :test_render
      assert "b", @response.body
    end
  end

  def test_which_chooses_non_existent_alternative
    ab_test(:simple) { }
    assert_raises ArgumentError do
      experiment(:simple).chooses(404)
    end
  end


  # -- Scoring --
 
  def test_scoring
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    # participating, conversions, rate, z-score
    # Control:      182	35 19.23%	N/A
    182.times { |i| experiment(:abcd).count i, :a, :participant }
    35.times  { |i| experiment(:abcd).count i, :a, :conversion }
    # Treatment A:  180	45 25.00%	1.33
    180.times { |i| experiment(:abcd).count i, :b, :participant }
    45.times  { |i| experiment(:abcd).count i, :b, :conversion }
    # treatment B:  189	28 14.81%	-1.13
    189.times { |i| experiment(:abcd).count i, :c, :participant }
    28.times  { |i| experiment(:abcd).count i, :c, :conversion }
    # treatment C:  188	61 32.45%	2.94
    188.times { |i| experiment(:abcd).count i, :d, :participant }
    61.times  { |i| experiment(:abcd).count i, :d, :conversion }

    z_scores = experiment(:abcd).score.alts.map { |alt| "%.2f" % alt.z_score }
    assert_equal %w{-1.33 0.00 -2.47 1.58}, z_scores
    confidences = experiment(:abcd).score.alts.map(&:confidence)
    assert_equal [90, 0, 99, 90], confidences

    diff = experiment(:abcd).score.alts.map { |alt| alt.difference && alt.difference.round }
    assert_equal [30, 69, nil, 119], diff
    assert_equal 3, experiment(:abcd).score.best.id
    assert_equal 3, experiment(:abcd).score.choice.id

    assert_equal 1, experiment(:abcd).score.base.id
    assert_equal 2, experiment(:abcd).score.least.id
  end

  def test_scoring_with_no_performers
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    assert experiment(:abcd).score.alts.all? { |alt| alt.z_score.nan? }
    assert experiment(:abcd).score.alts.all? { |alt| alt.confidence == 0 }
    assert experiment(:abcd).score.alts.all? { |alt| alt.difference.nil? }
    assert_nil experiment(:abcd).score.best
    assert_nil experiment(:abcd).score.choice
    assert_nil experiment(:abcd).score.least
  end

  def test_scoring_with_one_performer
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    10.times { |i| experiment(:abcd).count i, :b, :participant }
    8.times  { |i| experiment(:abcd).count i, :b, :conversion }
    assert experiment(:abcd).score.alts.all? { |alt| alt.z_score.nan? }
    assert experiment(:abcd).score.alts.all? { |alt| alt.confidence == 0 }
    assert experiment(:abcd).score.alts.all? { |alt| alt.difference.nil? }
    assert 1, experiment(:abcd).score.best.id
    assert_nil experiment(:abcd).score.choice
    assert 1, experiment(:abcd).score.base.id
    assert 1, experiment(:abcd).score.least.id
  end

  def test_scoring_with_some_performers
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    10.times { |i| experiment(:abcd).count i, :b, :participant }
    8.times  { |i| experiment(:abcd).count i, :b, :conversion }
    12.times { |i| experiment(:abcd).count i, :d, :participant }
    5.times  { |i| experiment(:abcd).count i, :d, :conversion }

    z_scores = experiment(:abcd).score.alts.map { |alt| "%.2f" % alt.z_score }
    assert_equal %w{NaN 2.01 NaN 0.00}, z_scores
    confidences = experiment(:abcd).score.alts.map(&:confidence)
    assert_equal [0, 95, 0, 0], confidences
    diff = experiment(:abcd).score.alts.map { |alt| alt.difference && alt.difference.round }
    assert_equal [nil, 92, nil, nil], diff
    assert_equal 1, experiment(:abcd).score.best.id
    assert_equal 1, experiment(:abcd).score.choice.id
    assert_equal 3, experiment(:abcd).score.base.id
    assert_equal 3, experiment(:abcd).score.least.id
  end


  # -- Conclusion --

  def test_conclusion
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    # participating, conversions, rate, z-score
    # Control:      182	35 19.23%	N/A
    182.times { |i| experiment(:abcd).count i, :a, :participant }
    35.times  { |i| experiment(:abcd).count i, :a, :conversion }
    # Treatment A:  180	45 25.00%	1.33
    180.times { |i| experiment(:abcd).count i, :b, :participant }
    45.times  { |i| experiment(:abcd).count i, :b, :conversion }
    # treatment B:  189	28 14.81%	-1.13
    189.times { |i| experiment(:abcd).count i, :c, :participant }
    28.times  { |i| experiment(:abcd).count i, :c, :conversion }
    # treatment C:  188	61 32.45%	2.94
    188.times { |i| experiment(:abcd).count i, :d, :participant }
    61.times  { |i| experiment(:abcd).count i, :d, :conversion }

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
The best choice is option D: it converted at 32.4% (30% better than option B).
With 90% probability this result is statistically significant.
Option B converted at 25.0%.
Option A converted at 19.2%.
Option C converted at 14.8%.
Option D selected as the best alternative.
    TEXT
  end

  def test_conclusion_with_some_performers
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    # Treatment A:  180	45 25.00%	1.33
    180.times { |i| experiment(:abcd).count i, :b, :participant }
    45.times  { |i| experiment(:abcd).count i, :b, :conversion }
    # treatment C:  188	61 32.45%	2.94
    188.times { |i| experiment(:abcd).count i, :d, :participant }
    61.times  { |i| experiment(:abcd).count i, :d, :conversion }

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
The best choice is option D: it converted at 32.4% (30% better than option B).
With 90% probability this result is statistically significant.
Option B converted at 25.0%.
Option A did not convert.
Option C did not convert.
Option D selected as the best alternative.
    TEXT
  end

  def test_conclusion_without_clear_winner
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    # Treatment A:  180	45 25.00%	1.33
    180.times { |i| experiment(:abcd).count i, :b, :participant }
    58.times  { |i| experiment(:abcd).count i, :b, :conversion }
    # treatment C:  188	61 32.45%	2.94
    188.times { |i| experiment(:abcd).count i, :d, :participant }
    61.times  { |i| experiment(:abcd).count i, :d, :conversion }

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
The best choice is option D: it converted at 32.4% (1% better than option B).
This result is not statistically significant, suggest you continue this experiment.
Option B converted at 32.2%.
Option A did not convert.
Option C did not convert.
    TEXT
  end

  def test_conclusion_without_close_performers
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    # Treatment A:  180	45 25.00%	1.33
    186.times { |i| experiment(:abcd).count i, :b, :participant }
    60.times  { |i| experiment(:abcd).count i, :b, :conversion }
    # treatment C:  188	61 32.45%	2.94
    188.times { |i| experiment(:abcd).count i, :d, :participant }
    61.times  { |i| experiment(:abcd).count i, :d, :conversion }

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
The best choice is option D: it converted at 32.4%.
This result is not statistically significant, suggest you continue this experiment.
Option B converted at 32.3%.
Option A did not convert.
Option C did not convert.
    TEXT
  end

  def test_conclusion_without_equal_performers
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    # Treatment A:  180	45 25.00%	1.33
    188.times { |i| experiment(:abcd).count i, :b, :participant }
    61.times  { |i| experiment(:abcd).count i, :b, :conversion }
    # treatment C:  188	61 32.45%	2.94
    188.times { |i| experiment(:abcd).count i, :d, :participant }
    61.times  { |i| experiment(:abcd).count i, :d, :conversion }

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
Option D converted at 32.4%.
Option B converted at 32.4%.
Option A did not convert.
Option C did not convert.
    TEXT
  end

  def test_conclusion_with_one_performers
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    # Treatment A:  180	45 25.00%	1.33
    180.times { |i| experiment(:abcd).count i, :b, :participant }
    45.times  { |i| experiment(:abcd).count i, :b, :conversion }

    assert_equal "This experiment did not run long enough to find a clear winner.", experiment(:abcd).conclusion.join("\n")
  end

  def test_conclusion_with_no_performers
    ab_test(:abcd) { alternatives :a, :b, :c, :d }
    assert_equal "This experiment did not run long enough to find a clear winner.", experiment(:abcd).conclusion.join("\n")
  end


  # -- Completion --

  def test_completion_if
    ab_test :simple do
      identify { rand }
      complete_if { true }
    end
    experiment(:simple).choose
    refute experiment(:simple).active?
  end

  def test_completion_if_fails
    ab_test :simple do
      identify { rand }
      complete_if { fail }
    end
    experiment(:simple).choose
    assert experiment(:simple).active?
  end

  def test_completion
    ids = Array.new(100) { |i| i.to_s }.shuffle
    ab_test :simple do
      identify { ids.pop }
      complete_if { alternatives.map(&:participants).sum >= 100 }
    end
    99.times do |i|
      experiment(:simple).choose
      assert experiment(:simple).active?
    end

    experiment(:simple).choose
    refute experiment(:simple).active?
  end

  def test_ab_methods_after_completion
    ids = Array.new(200) { |i| [i, i] }.shuffle.flatten
    ab_test :simple do
      identify { ids.pop }
      complete_if { alternatives.map(&:participants).sum >= 100 }
      outcome_is { alternatives[1] }
    end
    # Run experiment to completion (100 participants)
    results = Set.new
    100.times do
      results << experiment(:simple).choose
      experiment(:simple).conversion!
    end
    assert results.include?(true) && results.include?(false)
    refute experiment(:simple).active?

    # Test that we always get the same choice (true)
    100.times do
      assert_equal true, experiment(:simple).choose
      experiment(:simple).conversion!
    end
    # We don't get to count the 100 participant's conversion, but that's ok.
    assert_equal 99, experiment(:simple).alternatives.map(&:converted).sum
    assert_equal 99, experiment(:simple).alternatives.map(&:conversions).sum
  end


  # -- Outcome --
  
  def test_completion_outcome
    ab_test :quick do
      outcome_is { alternatives[1] }
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives[1], experiment(:quick).outcome
  end

  def test_outcome_is_returns_nil
    ab_test :quick do
      outcome_is { nil }
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives.first, experiment(:quick).outcome
  end

  def test_outcome_is_returns_something_else
    ab_test :quick do
      outcome_is { "error" }
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives.first, experiment(:quick).outcome
  end

  def test_outcome_is_fails
    ab_test :quick do
      outcome_is { fail }
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives.first, experiment(:quick).outcome
  end

  def test_outcome_choosing_best_alternative
    ab_test :quick do
    end
    2.times  { |i| experiment(:quick).count i, false, :participant }
    10.times { |i| experiment(:quick).count i, true }
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternative(true), experiment(:quick).outcome
  end

  def test_outcome_only_performing_alternative
    ab_test :quick do
    end
    2.times { |i| experiment(:quick).count i, true }
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternative(true), experiment(:quick).outcome
  end

  def test_outcome_choosing_equal_alternatives
    ab_test :quick do
    end
    8.times { |i| experiment(:quick).count i, false }
    8.times { |i| experiment(:quick).count i, true }
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternative(true), experiment(:quick).outcome
  end


  def ab_test(name, &block)
    Vanity.playground.define name, :ab_test, &block
  end
end
