require "test/test_helper"

class AbTestController < ActionController::Base
  use_vanity :current_user
  attr_accessor :current_user

  def test_render
    render :text=>ab_test(:simple)
  end

  def test_view
    render :inline=>"<%= ab_test(:simple) %>"
  end

  def test_capture
    if Rails.version.to_i == 3
      render :inline=>"<%= ab_test :simple do |value| %><%= value %><% end %>"
    else
      render :inline=>"<% ab_test :simple do |value| %><%= value %><% end %>"
    end
  end

  def track
    track! :coolness
    render :text=>""
  end
end


class AbTestTest < ActionController::TestCase
  tests AbTestController

  def setup
    super
    metric "Coolness"
  end

  # --  Experiment definition --

  def test_requires_at_least_two_alternatives_per_experiment
    assert_raises RuntimeError do
      new_ab_test :none do
        alternatives []
      end
    end
    assert_raises RuntimeError do
      new_ab_test :one do
        alternatives "foo"
      end
    end
    new_ab_test :two do
      alternatives "foo", "bar"
      metrics :coolness
    end
  end
  
  def test_returning_alternative_by_value
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    assert_equal experiment(:abcd).alternatives[1], experiment(:abcd).alternative(:b)
    assert_equal experiment(:abcd).alternatives[3], experiment(:abcd).alternative(:d)
  end

  def test_alternative_name
    new_ab_test :abcd do
      alternatives :a, :b
      metrics :coolness
    end
    assert_equal "option A", experiment(:abcd).alternative(:a).name
    assert_equal "option B", experiment(:abcd).alternative(:b).name
  end

  def test_alternative_fingerprint_is_unique
    new_ab_test :ab do
      metrics :coolness
      alternatives :a, :b
    end
    new_ab_test :cd do
      metrics :coolness
      alternatives :a, :b
    end
    fingerprints = Vanity.playground.experiments.map { |id, exp| exp.alternatives.map { |alt| exp.fingerprint(alt) } }.flatten
    assert_equal 4, fingerprints.uniq.size
  end

  def test_alternative_fingerprint_is_consistent
    new_ab_test :ab do
      alternatives :a, :b
      metrics :coolness
    end
    fingerprints = experiment(:ab).alternatives.map { |alt| experiment(:ab).fingerprint(alt) }
    fingerprints.each do |fingerprint|
      assert_match /^[0-9a-f]{10}$/i, fingerprint
    end
    assert_equal fingerprints.first, experiment(:ab).fingerprint(experiment(:ab).alternatives.first)
  end

  def test_ab_has_default
    new_ab_test :ice_cream_flavor do
      alternatives :a, :b, :c
      default :b
    end
    exp = experiment(:ice_cream_flavor)
    assert_equal exp.default, exp.alternative(:b)
  end

  def test_ab_sets_default_default
    new_ab_test :ice_cream_flavor do
      alternatives :a, :b, :c
      # no default specified
    end
    exp = experiment(:ice_cream_flavor)
    assert_equal exp.default, exp.alternative(:a)
  end

  def test_ab_overrides_unknown_default
    new_ab_test :ice_cream_flavor do
      alternatives :a, :b, :c
      default :badname
    end
    exp = experiment(:ice_cream_flavor)
    assert_equal exp.default, exp.alternative(:a)
  end

  def test_ab_can_only_set_default_once
    assert_raise ArgumentError do
      new_ab_test :ice_cream_flavor do
        alternative :a, :b, :c
        default :a
        default :b
      end
    end
  end

  def test_ab_can_only_have_one_default
    assert_raise ArgumentError do
      new_ab_test :ice_cream_flavor do
        alternative :a, :b, :c
        default :a, :b
      end
    end
  end

  def test_ab_cannot_get_default_before_specified
    assert_raise ArgumentError do
      new_ab_test :ice_cream_flavor do
        alternative :a, :b, :c
        default
      end
    end
  end

  def test_ab_accepts_nil_default
    new_ab_test :nil_default do
      alternatives nil, 'foo'
      default nil
    end
    exp = experiment(:nil_default)
    assert_equal exp.default, exp.alternative(nil)
  end

  def test_ab_chooses_nil_default_default
    new_ab_test :nil_default_default do
      alternatives nil, 'foo'
      # no default specified
    end
    exp = experiment(:nil_default_default)
    assert_equal exp.default, exp.alternative(nil)
  end

  # -- Experiment metric --

  def test_explicit_metric
    new_ab_test :abcd do
      metrics :coolness
    end
    assert_equal [Vanity.playground.metric(:coolness)], experiment(:abcd).metrics
  end

  def test_implicit_metric
    new_ab_test :abcd do
    end
    assert_equal [Vanity.playground.metric(:abcd)], experiment(:abcd).metrics
  end

  def test_metric_tracking_into_alternative
    metric "Coolness"
    new_ab_test :abcd do
      metrics :coolness
    end
    Vanity.playground.track! :coolness
    assert_equal 1, experiment(:abcd).alternatives.sum(&:conversions)
  end

  # -- use_js! --

  def test_does_not_record_participant_when_using_js
    Vanity.playground.use_js!
    ids = (0...10).to_a
    new_ab_test :foobar do
      alternatives "foo", "bar"
      identify { ids.pop }
      metrics :coolness
    end
    10.times { experiment(:foobar).choose }
    alts = experiment(:foobar).alternatives
    assert_equal 0, alts.map(&:participants).sum
  end


  # -- Running experiment --

  def test_returns_the_same_alternative_consistently
    new_ab_test :foobar do
      alternatives "foo", "bar"
      identify { "6e98ec" }
      metrics :coolness
    end
    assert value = experiment(:foobar).choose.value
    assert_match /foo|bar/, value
    1000.times do
      assert_equal value, experiment(:foobar).choose.value
    end
  end

  def test_returns_different_alternatives_for_each_participant
    new_ab_test :foobar do
      alternatives "foo", "bar"
      identify { rand }
      metrics :coolness
    end
    alts = Array.new(1000) { experiment(:foobar).choose.value }
    assert_equal %w{bar foo}, alts.uniq.sort
    assert_in_delta alts.select { |a| a == "foo" }.size, 500, 100 # this may fail, such is propability
  end

  def test_records_all_participants_in_each_alternative
    ids = (Array.new(200) { |i| i } * 5).shuffle
    new_ab_test :foobar do
      alternatives "foo", "bar"
      identify { ids.pop }
      metrics :coolness
    end
    1000.times { experiment(:foobar).choose }
    alts = experiment(:foobar).alternatives
    assert_equal 200, alts.map(&:participants).sum
    assert_in_delta alts.first.participants, 100, 20
  end

  def test_records_each_converted_participant_only_once
    ids = ((1..100).map { |i| [i,i] } * 5).shuffle.flatten # 3,3,1,1,7,7 etc
    new_ab_test :foobar do
      alternatives "foo", "bar"
      identify { ids.pop }
      metrics :coolness
    end
    500.times do
      experiment(:foobar).choose
      metric(:coolness).track!
    end
    alts = experiment(:foobar).alternatives
    assert_equal 100, alts.map(&:converted).sum
  end

  def test_records_conversion_only_for_participants
    ids = ((1..100).map { |i| [-i,i,i] } * 5).shuffle.flatten # -3,3,3,-1,1,1,-7,7,7 etc
    new_ab_test :foobar do
      alternatives "foo", "bar"
      identify { ids.pop }
      metrics :coolness
    end
    500.times do
      experiment(:foobar).choose
      metric(:coolness).track!
      metric(:coolness).track!
    end
    alts = experiment(:foobar).alternatives
    assert_equal 100, alts.map(&:converted).sum
  end


  def test_destroy_experiment
    new_ab_test :simple do
      identify { "me" }
      metrics :coolness
      complete_if { alternatives.map(&:converted).sum >= 1 }
      outcome_is { alternative(true) }
    end
    experiment(:simple).choose
    metric(:coolness).track!
    assert !experiment(:simple).active?
    assert_equal true, experiment(:simple).outcome.value

    experiment(:simple).destroy
    assert experiment(:simple).active?
    assert_nil experiment(:simple).outcome
    assert_nil experiment(:simple).completed_at
    assert_equal 0, experiment(:simple).alternatives.map(&:participants).sum
    assert_equal 0, experiment(:simple).alternatives.map(&:conversions).sum
    assert_equal 0, experiment(:simple).alternatives.map(&:converted).sum
  end


  # -- A/B helper methods --

  def test_fail_if_no_experiment
    assert_raise Vanity::NoExperimentError do
      get :test_render
    end
  end

  def test_ab_test_chooses_in_render
    new_ab_test :simple do
      metrics :coolness
    end
    responses = Array.new(100) do
      @controller = nil ; setup_controller_request_and_response
      get :test_render
      @response.body
    end
    assert_equal %w{false true}, responses.uniq.sort
  end

  def test_ab_test_chooses_view_helper
    new_ab_test :simple do
      metrics :coolness
    end
    responses = Array.new(100) do
      @controller = nil ; setup_controller_request_and_response
      get :test_view
      @response.body
    end
    assert_equal %w{false true}, responses.uniq.sort
  end

  def test_ab_test_with_capture
    new_ab_test :simple do
      metrics :coolness
    end
    responses = Array.new(100) do
      @controller = nil ; setup_controller_request_and_response
      get :test_capture
      @response.body
    end
    assert_equal %w{false true}, responses.map(&:strip).uniq.sort
  end

  def test_ab_test_track
    new_ab_test :simple do
      metrics :coolness
    end
    responses = Array.new(100) do
      @controller.send(:cookies).each{ |cookie| @controller.send(:cookies).delete(cookie.first) }
      get :track
      @response.body
    end
  end


  # -- Testing with tests --
  
  def test_with_given_choice
    new_ab_test :simple do
      alternatives :a, :b, :c
      metrics :coolness
    end
    100.times do |i|
      @controller = nil ; setup_controller_request_and_response
      experiment(:simple).chooses(:b)
      get :test_render
      assert "b", @response.body
    end
  end

  def test_which_chooses_non_existent_alternative
    new_ab_test :simple do
      metrics :coolness
    end
    assert_raises ArgumentError do
      experiment(:simple).chooses(404)
    end
  end

  def test_chooses_cleared_with_nil
    new_ab_test :simple  do
      identify { rand }
      alternatives :a, :b, :c
      metrics :coolness
    end
    responses = Array.new(100) { |i|
      @controller = nil ; setup_controller_request_and_response
      experiment(:simple).chooses(:b)
      experiment(:simple).chooses(nil)
      get :test_render
      @response.body
    }
    assert responses.uniq.size == 3
  end


  # -- Scoring --
  
  def test_scoring
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    # participating, conversions, rate, z-score
    # Control:      182	35 19.23%	N/A
    # Treatment A:  180	45 25.00%	1.33
    # treatment B:  189	28 14.81%	-1.13
    # treatment C:  188	61 32.45%	2.94
    fake :abcd, :a=>[182, 35], :b=>[180, 45], :c=>[189,28], :d=>[188, 61]

    z_scores = experiment(:abcd).score.alts.map { |alt| "%.2f" % alt.z_score }
    assert_equal %w{-1.33 0.00 -2.46 1.58}, z_scores
    probabilities = experiment(:abcd).score.alts.map(&:probability)
    assert_equal [90, 0, 99, 90], probabilities

    diff = experiment(:abcd).score.alts.map { |alt| alt.difference && alt.difference.round }
    assert_equal [30, 69, nil, 119], diff
    assert_equal 3, experiment(:abcd).score.best.id
    assert_equal 3, experiment(:abcd).score.choice.id

    assert_equal 1, experiment(:abcd).score.base.id
    assert_equal 2, experiment(:abcd).score.least.id
  end

  def test_scoring_with_no_performers
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    assert experiment(:abcd).score.alts.all? { |alt| alt.z_score.nan? }
    assert experiment(:abcd).score.alts.all? { |alt| alt.probability == 0 }
    assert experiment(:abcd).score.alts.all? { |alt| alt.difference.nil? }
    assert_nil experiment(:abcd).score.best
    assert_nil experiment(:abcd).score.choice
    assert_nil experiment(:abcd).score.least
  end

  def test_scoring_with_one_performer
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    fake :abcd, :b=>[10,8]
    assert experiment(:abcd).score.alts.all? { |alt| alt.z_score.nan? }
    assert experiment(:abcd).score.alts.all? { |alt| alt.probability == 0 }
    assert experiment(:abcd).score.alts.all? { |alt| alt.difference.nil? }
    assert_equal 1, experiment(:abcd).score.best.id
    assert_nil experiment(:abcd).score.choice
    assert_equal 2, experiment(:abcd).score.base.id
    assert_equal 1, experiment(:abcd).score.least.id
  end

  def test_scoring_with_some_performers
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    fake :abcd, :b=>[10,8], :d=>[12,5]

    z_scores = experiment(:abcd).score.alts.map { |alt| "%.2f" % alt.z_score }.map(&:downcase)
    assert_equal %w{nan 2.01 nan 0.00}, z_scores
    probabilities = experiment(:abcd).score.alts.map(&:probability)
    assert_equal [0, 95, 0, 0], probabilities
    diff = experiment(:abcd).score.alts.map { |alt| alt.difference && alt.difference.round }
    assert_equal [nil, 92, nil, nil], diff
    assert_equal 1, experiment(:abcd).score.best.id
    assert_equal 1, experiment(:abcd).score.choice.id
    assert_equal 3, experiment(:abcd).score.base.id
    assert_equal 3, experiment(:abcd).score.least.id
  end

  def test_scoring_with_different_probability
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    fake :abcd, :b=>[10,8], :d=>[12,5]

    assert_equal 1, experiment(:abcd).score(90).choice.id
    assert_equal 1, experiment(:abcd).score(95).choice.id
    assert_nil experiment(:abcd).score(99).choice
  end


  # -- Conclusion --

  def test_conclusion
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    # participating, conversions, rate, z-score
    # Control:      182	35 19.23%	N/A
    # Treatment A:  180	45 25.00%	1.33
    # treatment B:  189	28 14.81%	-1.13
    # treatment C:  188	61 32.45%	2.94
    fake :abcd, :a=>[182, 35], :b=>[180, 45], :c=>[189,28], :d=>[188, 61]

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
There are 739 participants in this experiment.
The best choice is option D: it converted at 32.4% (30% better than option B).
With 90% probability this result is statistically significant.
Option B converted at 25.0%.
Option A converted at 19.2%.
Option C converted at 14.8%.
Option D selected as the best alternative.
    TEXT
  end

  def test_conclusion_with_some_performers
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    fake :abcd, :b=>[180, 45], :d=>[188, 61]

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
There are 368 participants in this experiment.
The best choice is option D: it converted at 32.4% (30% better than option B).
With 90% probability this result is statistically significant.
Option B converted at 25.0%.
Option A did not convert.
Option C did not convert.
Option D selected as the best alternative.
    TEXT
  end

  def test_conclusion_without_clear_winner
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    fake :abcd, :b=>[180, 58], :d=>[188, 61]

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
There are 368 participants in this experiment.
The best choice is option D: it converted at 32.4% (1% better than option B).
This result is not statistically significant, suggest you continue this experiment.
Option B converted at 32.2%.
Option A did not convert.
Option C did not convert.
    TEXT
  end

  def test_conclusion_without_close_performers
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    fake :abcd, :b=>[186, 60], :d=>[188, 61]

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
There are 374 participants in this experiment.
The best choice is option D: it converted at 32.4% (1% better than option B).
This result is not statistically significant, suggest you continue this experiment.
Option B converted at 32.3%.
Option A did not convert.
Option C did not convert.
    TEXT
  end

  def test_conclusion_without_equal_performers
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    fake :abcd, :b=>[188, 61], :d=>[188, 61]

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
There are 376 participants in this experiment.
Option D converted at 32.4%.
Option B converted at 32.4%.
Option A did not convert.
Option C did not convert.
    TEXT
  end

  def test_conclusion_with_one_performers
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    fake :abcd, :b=>[180, 45]

    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
There are 180 participants in this experiment.
This experiment did not run long enough to find a clear winner.
    TEXT
  end

  def test_conclusion_with_no_performers
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      metrics :coolness
    end
    assert_equal <<-TEXT, experiment(:abcd).conclusion.join("\n") << "\n"
There are no participants in this experiment yet.
This experiment did not run long enough to find a clear winner.
    TEXT
  end


  # -- Completion --

  def test_completion_if
    new_ab_test :simple do
      identify { rand }
      complete_if { true }
      metrics :coolness
    end
    experiment(:simple).choose
    assert !experiment(:simple).active?
  end

  def test_completion_if_fails
    new_ab_test :simple do
      identify { rand }
      complete_if { fail "Testing complete_if raises exception" }
      metrics :coolness
    end
    experiment(:simple).choose
    assert experiment(:simple).active?
  end

  def test_completion
    ids = Array.new(100) { |i| i.to_s }.shuffle
    new_ab_test :simple do
      identify { ids.pop }
      complete_if { alternatives.map(&:participants).sum >= 100 }
      metrics :coolness
    end
    99.times do |i|
      experiment(:simple).choose
      assert experiment(:simple).active?
    end

    experiment(:simple).choose
    assert !experiment(:simple).active?
  end

  def test_ab_methods_after_completion
    ids = Array.new(200) { |i| [i, i] }.shuffle.flatten
    new_ab_test :simple do
      identify { ids.pop }
      complete_if { alternatives.map(&:participants).sum >= 100 }
      outcome_is { alternatives[1] }
      metrics :coolness
    end
    # Run experiment to completion (100 participants)
    results = Set.new
    100.times do
      results << experiment(:simple).choose.value
      metric(:coolness).track!
    end
    assert results.include?(true) && results.include?(false)
    assert !experiment(:simple).active?

    # Test that we always get the same choice (true)
    100.times do
      assert_equal true, experiment(:simple).choose.value
      metric(:coolness).track!
    end
    # We don't get to count the 100 participant's conversion, but that's ok.
    assert_equal 99, experiment(:simple).alternatives.map(&:converted).sum
    assert_equal 99, experiment(:simple).alternatives.map(&:conversions).sum
  end


  # -- Outcome --
  
  def test_completion_outcome
    new_ab_test :quick do
      outcome_is { alternatives[1] }
      metrics :coolness
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives[1], experiment(:quick).outcome
  end

  def test_error_in_completion
    new_ab_test :quick do
      outcome_is { raise RuntimeError }
      metrics :coolness
    end
    e = experiment(:quick)
    e.expects(:warn)
    assert_nothing_raised do
      e.complete!
    end
  end

  def test_outcome_is_returns_nil
    new_ab_test :quick do
      outcome_is { nil }
      metrics :coolness
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives.first, experiment(:quick).outcome
  end

  def test_outcome_is_returns_something_else
    new_ab_test :quick do
      outcome_is { "error" }
      metrics :coolness
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives.first, experiment(:quick).outcome
  end

  def test_outcome_is_fails
    new_ab_test :quick do
      outcome_is { fail "Testing outcome_is raising exception" }
      metrics :coolness
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives.first, experiment(:quick).outcome
  end

  def test_outcome_choosing_best_alternative
    new_ab_test :quick do
      metrics :coolness
    end
    fake :quick, false=>[2,0], true=>10
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternative(true), experiment(:quick).outcome
  end

  def test_outcome_only_performing_alternative
    new_ab_test :quick do
      metrics :coolness
    end
    fake :quick, true=>2
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternative(true), experiment(:quick).outcome
  end

  def test_outcome_choosing_equal_alternatives
    new_ab_test :quick do
      metrics :coolness
    end
    fake :quick, false=>8, true=>8
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternative(true), experiment(:quick).outcome
  end


  # -- No collection --

  def test_no_collection_does_not_track
    not_collecting!
    metric "Coolness"
    new_ab_test :abcd do
      metrics :coolness
    end
    Vanity.playground.track! :coolness
    assert_equal 0, experiment(:abcd).alternatives.sum(&:conversions)
  end

  def test_no_collection_and_completion
    not_collecting!
    new_ab_test :quick do
      outcome_is { alternatives[1] }
      metrics :coolness
    end
    experiment(:quick).complete!
    assert_nil experiment(:quick).outcome
  end

  def test_chooses_records_participants
    new_ab_test :simple do
      alternatives :a, :b, :c
      metrics :coolness
    end
    experiment(:simple).chooses(:b)
    assert_equal experiment(:simple).alternatives[1].participants, 1
  end

  def test_chooses_moves_participant_to_new_alternative
    new_ab_test :simple do
      alternatives :a, :b, :c
      metrics :coolness
      identify { "1" }
    end
    val = experiment(:simple).choose.value
    alternative = experiment(:simple).alternatives.detect {|a| a.value != val }
    experiment(:simple).chooses(alternative.value)
    assert_equal experiment(:simple).choose.value, alternative.value
    experiment(:simple).chooses(val)
    assert_equal experiment(:simple).choose.value, val
  end

  def test_chooses_records_participants_only_once
    new_ab_test :simple do
      alternatives :a, :b, :c
      metrics :coolness
    end
    2.times { experiment(:simple).chooses(:b) }
    assert_equal experiment(:simple).alternatives[1].participants, 1
  end

  def test_chooses_records_participants_for_new_alternatives
    new_ab_test :simple do
      alternatives :a, :b, :c
      metrics :coolness
    end
    experiment(:simple).chooses(:b)
    experiment(:simple).chooses(:c)
    assert_equal experiment(:simple).alternatives[2].participants, 1
  end

  def test_no_collection_and_chooses
    not_collecting!
    new_ab_test :simple do
      alternatives :a, :b, :c
      metrics :coolness
    end
    assert !experiment(:simple).showing?(experiment(:simple).alternatives[1])
    experiment(:simple).chooses(:b)
    assert experiment(:simple).showing?(experiment(:simple).alternatives[1])
    assert !experiment(:simple).showing?(experiment(:simple).alternatives[2])
  end

  def test_no_collection_chooses_without_database
    not_collecting!
    new_ab_test :simple do
      alternatives :a, :b, :c
      metrics :coolness
    end
    choice = experiment(:simple).choose.value
    assert [:a, :b, :c].include?(choice)
    assert_equal choice, experiment(:simple).choose.value
  end


  # -- Helper methods --

  def fake(name, args)
    experiment(name).instance_eval { fake args }
  end

end
