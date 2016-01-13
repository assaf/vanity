require "test_helper"

class AbTestController < ActionController::Base
  use_vanity :current_user
  attr_accessor :current_user

  def test_render
    render :text=>Vanity.ab_test(:simple)
  end

  def test_view
    render :inline=>"<%= ab_test(:simple) %>"
  end

  def test_capture
    render :inline=>"<%= ab_test(:simple) do |value| %><%= value %><% end %>"
  end

  def track
    Vanity.track!(:coolness)
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
        default nil
      end
    end
    assert_raises RuntimeError do
      new_ab_test :one do
        alternatives "foo"
        default "foo"
      end
    end
    new_ab_test :two do
      alternatives "foo", "bar"
      default "foo"
      metrics :coolness
    end
  end

  def test_returning_alternative_by_value
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      default :a
      metrics :coolness
    end
    assert_equal experiment(:abcd).alternatives[1], experiment(:abcd).alternative(:b)
    assert_equal experiment(:abcd).alternatives[3], experiment(:abcd).alternative(:d)
  end

  def test_alternative_name
    new_ab_test :abcd do
      alternatives :a, :b
      default :a
      metrics :coolness
    end
    assert_equal "option A", experiment(:abcd).alternative(:a).name
    assert_equal "option B", experiment(:abcd).alternative(:b).name
  end

  def test_alternative_fingerprint_is_unique
    new_ab_test :ab do
      metrics :coolness
      alternatives :a, :b
      default :a
    end
    new_ab_test :cd do
      metrics :coolness
      alternatives :a, :b
      default :a
    end
    fingerprints = Vanity.playground.experiments.map { |id, exp| exp.alternatives.map { |alt| exp.fingerprint(alt) } }.flatten
    assert_equal 4, fingerprints.uniq.size
  end

  def test_alternative_fingerprint_is_consistent
    new_ab_test :ab do
      alternatives :a, :b
      default :a
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
      metrics :coolness
      alternatives :a, :b, :c
      default :b
    end
    exp = experiment(:ice_cream_flavor)
    assert_equal exp.default, exp.alternative(:b)
  end

  def test_ab_sets_default_default
    new_ab_test :ice_cream_flavor do
      metrics :coolness
      alternatives :a, :b, :c
      # no default specified
    end
    exp = experiment(:ice_cream_flavor)
    assert_equal exp.default, exp.alternative(:a)
  end

  def test_ab_overrides_unknown_default
    new_ab_test :ice_cream_flavor do
      metrics :coolness
      alternatives :a, :b, :c
      default :badname
    end
    exp = experiment(:ice_cream_flavor)
    assert_equal exp.default, exp.alternative(:a)
  end

  def test_ab_can_only_set_default_once
    assert_raise ArgumentError do
      new_ab_test :ice_cream_flavor do
        metrics :coolness
        alternative :a, :b, :c
        default :a
        default :b
      end
    end
  end

  def test_ab_can_only_have_one_default
    assert_raise ArgumentError do
      new_ab_test :ice_cream_flavor do
        metrics :coolness
        alternative :a, :b, :c
        default :a, :b
      end
    end
  end

  def test_ab_cannot_get_default_before_specified
    assert_raise ArgumentError do
      new_ab_test :ice_cream_flavor do
        metrics :coolness
        alternative :a, :b, :c
        default
      end
    end
  end

  def test_ab_accepts_nil_default
    new_ab_test :nil_default do
      metrics :coolness
      alternatives nil, 'foo'
      default nil
    end
    exp = experiment(:nil_default)
    assert_equal exp.default, exp.alternative(nil)
  end

  def test_ab_chooses_nil_default_default
    new_ab_test :nil_default_default do
      metrics :coolness
      alternatives nil, 'foo'
      # no default specified
    end
    exp = experiment(:nil_default_default)
    assert_equal exp.default, exp.alternative(nil)
  end
  
  
  # -- Experiment Enabled/disabled --
  
  # @example new test should be enabled regardless of collecting?
  #   regardless_of "Vanity.playground.collecting" do
  #     assert (new_ab_test :test).enabled?
  #   end
  def regardless_of(attr_name, &block)
    prev_val = eval "#{attr_name}?"
    
    eval "#{attr_name}=true"
    block.call(eval "#{attr_name}?")
    nuke_playground
    
    eval "#{attr_name}=false"
    block.call(eval "#{attr_name}?")
    nuke_playground
    
    eval "#{attr_name}=prev_val"
  end
  
  def test_new_test_is_disabled_when_experiments_start_enabled_is_false
    Vanity.configuration.experiments_start_enabled = false
    exp = new_ab_test :test, enable: false do
      metrics :coolness
      default false
    end
    assert !exp.enabled?
  end

  def test_new_test_is_enabled_when_experiments_start_enabled_is_true
    Vanity.configuration.experiments_start_enabled = true
    exp = new_ab_test :test, enable: false do
      metrics :coolness
      default false
    end
    assert exp.enabled?
  end
  
  def test_complete_sets_enabled_false
    Vanity.playground.collecting = true
    exp = new_ab_test :test do
      metrics :coolness
      default false
    end
    exp.complete! #active? => false

    assert !exp.enabled?, "experiment should not be enabled but it is!"
  end

  def test_complete_keeps_enabled_true_while_not_collecting
    exp = new_ab_test :test do
      metrics :coolness
      default false
    end
    Vanity.playground.collecting = false
    exp.enabled = false
    assert exp.enabled?
  end

  def test_set_enabled_while_active
    Vanity.playground.collecting = true
    exp = new_ab_test :test do
      metrics :coolness
      default false
    end
    
    exp.enabled = true
    assert exp.enabled?
    
    exp.enabled = false
    assert !exp.enabled?
  end
  
  def test_cannot_set_enabled_for_inactive
    Vanity.playground.collecting = true
    exp = new_ab_test :test do
      metrics :coolness
      default false
    end
    exp.complete! #active? => false
    assert !exp.enabled?
    exp.enabled = true
    assert !exp.enabled?
  end

  def test_always_enabled_while_not_collecting
    Vanity.playground.collecting = false
    exp = new_ab_test :test do
      metrics :coolness
      default false
    end
    assert exp.enabled?
    exp.enabled = false
    assert exp.enabled?
  end
  
  def test_enabled_persists_across_definitions
    Vanity.configuration.experiments_start_enabled = false
    Vanity.playground.collecting = true
    new_ab_test :test, :enable => false do 
      metrics :coolness
      default false
    end
    assert !experiment(:test).enabled? #starts off false
    
    new_playground
    metric "Coolness"
    
    new_ab_test :test, :enable => false do
      metrics :coolness
      default false
    end
    assert !experiment(:test).enabled? #still false
    experiment(:test).enabled = true
    assert experiment(:test).enabled? #now true
    
    new_playground
    metric "Coolness"
    
    new_ab_test :test, :enable => false do
      metrics :coolness
      default false
    end
    assert experiment(:test).enabled? #still true
    experiment(:test).enabled = false
    assert !experiment(:test).enabled? #now false again
  end

  def test_enabled_persists_across_definitions_when_starting_enabled
    Vanity.configuration.experiments_start_enabled = true
    Vanity.playground.collecting = true
    new_ab_test :test, :enable => false do 
      metrics :coolness
      default false
    end
    assert experiment(:test).enabled? #starts off true
    
    new_playground
    metric "Coolness"
    
    new_ab_test :test, :enable => false do
      metrics :coolness
      default false
    end
    assert experiment(:test).enabled? #still true
    experiment(:test).enabled = false
    assert !experiment(:test).enabled? #now false
    
    new_playground
    metric "Coolness"
    
    new_ab_test :test, :enable => false do
      metrics :coolness
      default false
    end
    assert !experiment(:test).enabled? #still false
    experiment(:test).enabled = true
    assert experiment(:test).enabled? #now true again
  end
  
  def test_choose_random_when_enabled
    metric "Coolness"

    exp = new_ab_test :test do 
      metrics :coolness
      true_false
      default false
      identify { rand }
    end
    results = Set.new
    100.times do
      results << exp.choose.value
    end
    assert_equal results, [true, false].to_set
  end
  
  def test_choose_default_when_disabled
    exp = new_ab_test :test do
      metrics :coolness
      alternatives 0, 1, 2, 3, 4, 5
      default 3
    end
    
    exp.enabled = false
    100.times.each do
      assert_equal 3, exp.choose.value
    end
  end
  
  def test_choose_outcome_when_finished
    exp = new_ab_test :test do
      metrics :coolness
      alternatives 0,1,2,3,4,5
      default 3
      outcome_is { alternative(5) }
    end
    exp.complete!
    100.times.each do
      assert_equal 5, exp.choose.value
    end
  end
  
  # -- Experiment metric --

  def test_explicit_metric
    new_ab_test :abcd do
      metrics :coolness
      default false
    end
    assert_equal [Vanity.playground.metric(:coolness)], experiment(:abcd).metrics
  end

  def test_implicit_metric
    new_ab_test :abcd do
      default false
    end
    assert_equal [Vanity.playground.metric(:abcd)], experiment(:abcd).metrics
  end

  def test_metric_tracking_into_alternative
    metric "Coolness"
    new_ab_test :abcd do
      metrics :coolness
      default false
    end
    Vanity.playground.track! :coolness
    assert_equal 1, experiment(:abcd).alternatives.sum(&:conversions)
  end

  # -- track! --

  def test_track_with_identity_overrides_default
    identities = ["quux"]
    new_ab_test :foobar do
      default "foo"
      alternatives "foo", "bar"
      identify { identities.pop || "6e98ec" }
      metrics :coolness
    end
    2.times { experiment(:foobar).choose }
    assert_equal 0, experiment(:foobar).alternatives.sum(&:converted)
    experiment(:foobar).track!(:coolness, Time.now, 1)
    assert_equal 1, experiment(:foobar).alternatives.sum(&:converted)
    experiment(:foobar).track!(:coolness, Time.now, 1, :identity=>"quux")
    assert_equal 2, experiment(:foobar).alternatives.sum(&:converted)
  end

  # -- use_js! --

  def test_choose_does_not_record_participant_when_using_js
    Vanity.configuration.use_js = true
    ids = (0...10).to_a
    new_ab_test :foobar do
      default "foo"
      alternatives "foo", "bar"
      identify { ids.pop }
      metrics :coolness
    end
    10.times { experiment(:foobar).choose }
    alts = experiment(:foobar).alternatives
    assert_equal 0, alts.map(&:participants).sum
  end

  # -- on_assignment --

  def test_calls_on_assignment_on_new_assignment
    on_assignment_called_times = 0
    new_ab_test :foobar do
      default "foo"
      alternatives "foo", "bar"
      identify { "6e98ec" }
      metrics :coolness
      on_assignment { on_assignment_called_times = on_assignment_called_times+1 }
    end
    2.times { experiment(:foobar).choose }
    assert_equal 1, on_assignment_called_times
  end

  def test_calls_on_assignment_when_given_valid_request
    on_assignment_called_times = 0
    new_ab_test :foobar do
      default "foo"
      alternatives "foo", "bar"
      identify { "6e98ec" }
      metrics :coolness
      on_assignment { on_assignment_called_times = on_assignment_called_times+1 }
    end
    experiment(:foobar).choose(dummy_request)
    assert_equal 1, on_assignment_called_times
  end

  def test_does_not_call_on_assignment_when_given_invalid_request
    on_assignment_called_times = 0
    new_ab_test :foobar do
      default "foo"
      alternatives "foo", "bar"
      identify { "6e98ec" }
      metrics :coolness
      on_assignment { on_assignment_called_times = on_assignment_called_times+1 }
    end
    request = dummy_request
    request.user_agent = "Googlebot/2.1 ( http://www.google.com/bot.html)"
    experiment(:foobar).choose(request)
    assert_equal 0, on_assignment_called_times
  end

  def test_calls_on_assignment_on_new_assignment_via_chooses
    on_assignment_called_times = 0
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
      identify { "6e98ec" }
      metrics :coolness
      on_assignment { on_assignment_called_times = on_assignment_called_times+1 }
    end
    2.times { experiment(:foobar).chooses("foo") }
    assert_equal 1, on_assignment_called_times
  end

  def test_returns_the_same_alternative_consistently_when_on_assignment_is_set
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
      identify { "6e98ec" }
      on_assignment {}
      metrics :coolness
    end
    assert value = experiment(:foobar).choose.value
    assert_match /foo|bar/, value
    1000.times do
      assert_equal value, experiment(:foobar).choose.value
    end
  end

  # -- ab_assigned --

  def test_ab_assigned
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
      identify { "6e98ec" }
      metrics :coolness
    end
    assert_equal nil, experiment(:foobar).playground.connection.ab_assigned(experiment(:foobar).id, "6e98ec")
    assert id = experiment(:foobar).choose.id
    assert_equal id, experiment(:foobar).playground.connection.ab_assigned(experiment(:foobar).id, "6e98ec")
  end

  def test_ab_assigned
    identity = { :a => :b }
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
      identify { identity }
      metrics :coolness
    end
    assert_equal nil, experiment(:foobar).playground.connection.ab_assigned(experiment(:foobar).id, identity)
    assert id = experiment(:foobar).choose.id
    assert_equal id, experiment(:foobar).playground.connection.ab_assigned(experiment(:foobar).id, identity)
  end

  # -- Unequal probabilities --

  def test_returns_the_same_alternative_consistently_when_using_probabilities
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
      identify { "6e98ec" }
      rebalance_frequency 10
      metrics :coolness
    end
    value = experiment(:foobar).choose.value
    assert value
    assert_match /foo|bar/, value
    100.times do
      assert_equal value, experiment(:foobar).choose.value
    end
  end

  def test_uses_configured_probabilities_for_new_assignments
    new_ab_test :foobar do
      alternatives "foo" => 30, "bar" => 60
      identify { rand }
      metrics :coolness
    end
    alts = Array.new(10_000) { experiment(:foobar).choose.value }.reduce({}) { |h,k| h[k] ||= 0; h[k] += 1; h }
    assert_equal %w{bar foo}, alts.keys.sort
    assert_in_delta 3333, alts["foo"], 200 # this may fail, such is propability
  end

  def test_uses_probabilities_for_new_assignments
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
      identify { rand }
      rebalance_frequency 10000
      metrics :coolness
    end
    altered_alts = experiment(:foobar).alternatives
    altered_alts[0].probability=30
    altered_alts[1].probability=70
    experiment(:foobar).set_alternative_probabilities altered_alts
    alts = Array.new(600) { experiment(:foobar).choose.value }
    assert_equal %w{bar foo}, alts.uniq.sort
    assert_in_delta alts.select { |a| a == altered_alts[0].value }.size, 200, 60 # this may fail, such is propability
  end

  # -- Rebalancing probabilities --

  def test_rebalances_probabilities_after_rebalance_frequency_calls
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
      identify { rand }
      rebalance_frequency 12
      metrics :coolness
    end
    class <<experiment(:foobar)
      def times_called
        @times_called || 0
      end
      def rebalance!
        @times_called = times_called + 1
      end
    end
    11.times { experiment(:foobar).choose.value }
    assert_equal 0, experiment(:foobar).times_called
    experiment(:foobar).choose.value
    assert_equal 1, experiment(:foobar).times_called
    12.times { experiment(:foobar).choose.value }
    assert_equal 2, experiment(:foobar).times_called
  end

  def test_rebalance_uses_bayes_score_probabilities_to_update_probabilities
    new_ab_test :foobar do
      alternatives "foo", "bar", "baa"
      default "foo"
      identify { rand }
      rebalance_frequency 12
      metrics :coolness
    end
    corresponding_probabilities = [[experiment(:foobar).alternatives[0], 0.3], [experiment(:foobar).alternatives[1], 0.6], [experiment(:foobar).alternatives[2], 1.0]]

    class <<experiment(:foobar)
      def was_called
        @was_called
      end
      def bayes_bandit_score(probability=90)
        @was_called = true
        altered_alts = Vanity.playground.experiment(:foobar).alternatives
        altered_alts[0].probability=30
        altered_alts[1].probability=30
        altered_alts[2].probability=40
        Struct.new(:alts,:method).new(altered_alts,:bayes_bandit_score)
      end
      def use_probabilities
        @use_probabilities
      end
    end
    experiment(:foobar).rebalance!
    assert experiment(:foobar).was_called
    assert_equal experiment(:foobar).use_probabilities, corresponding_probabilities
  end

  # -- Running experiment --

  def test_returns_the_same_alternative_consistently
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
      identify { "6e98ec" }
      metrics :coolness
    end
    assert value = experiment(:foobar).choose.value
    assert_match /foo|bar/, value
    1000.times do
      assert_equal value, experiment(:foobar).choose.value
    end
  end

  def test_respects_out_of_band_assignment
    new_ab_test :foobar do
      alternatives "a", "b", "c"
      default "a"
      identify { "6e98ec" }
      metrics :coolness
    end
    # Note that this is explicitly not the alternative id that alternative_for
    # would assign based on identity
    assigned_alternative_id = 1
    Vanity.playground.connection.ab_add_participant(
      experiment(:foobar).id,
      assigned_alternative_id,
      "6e98ec"
    )
    chosen_alternative_id = experiment(:foobar).choose.id
    assert_equal assigned_alternative_id, chosen_alternative_id
  end

  def test_returns_different_alternatives_for_each_participant
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
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
      default "foo"
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
      default "foo"
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
      default "foo"
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

  def test_choose_records_participants_given_a_valid_request
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
      identify { "me" }
      metrics :coolness
    end
    experiment(:foobar).choose(dummy_request)
    assert_equal 1, experiment(:foobar).alternatives.map(&:participants).sum
  end

  def test_choose_ignores_participants_given_an_invalid_request
    new_ab_test :foobar do
      alternatives "foo", "bar"
      default "foo"
      identify { "me" }
      metrics :coolness
    end
    request = dummy_request
    request.user_agent = "Googlebot/2.1 ( http://www.google.com/bot.html)"
    experiment(:foobar).choose(request)
    assert_equal 0, experiment(:foobar).alternatives.map(&:participants).sum
  end

  def test_destroy_experiment
    new_ab_test :simple do
      identify { "me" }
      metrics :coolness
      default false
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
      default false
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
      default false
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
      default false
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
      default false
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
      default :a
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
      default false
    end
    assert_raises ArgumentError do
      experiment(:simple).chooses(404)
    end
  end

  def test_chooses_cleared_with_nil
    new_ab_test :simple  do
      identify { rand }
      alternatives :a, :b, :c
      default :a
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

  def test_calculate_score
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      default :a
      metrics :coolness
    end
    score_result = experiment(:abcd).calculate_score
    assert_equal :score, score_result.method

    new_ab_test :bayes_abcd do
      alternatives :a, :b, :c, :d
      default :a
      metrics :coolness
      score_method :bayes_bandit_score
    end
    bayes_score_result = experiment(:bayes_abcd).calculate_score
    assert_equal :bayes_bandit_score, bayes_score_result.method
  end

  def test_scoring
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      default :a
      metrics :coolness
    end
    # participating, conversions, rate, z-score
    # Control:      182 35 19.23% N/A
    # Treatment A:  180 45 25.00% 1.33
    # treatment B:  189 28 14.81% -1.13
    # treatment C:  188 61 32.45% 2.94
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

  def test_bayes_scoring
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      default :a
      metrics :coolness
    end
    # participating, conversions, rate, z-score
    # Control:      182 35 19.23% N/A
    # Treatment A:  180 45 25.00% 1.33
    # treatment B:  189 28 14.81% -1.13
    # treatment C:  188 61 32.45% 2.94
    fake :abcd, :a=>[182, 35], :b=>[180, 45], :c=>[189,28], :d=>[188, 61]

    score_result = experiment(:abcd).bayes_bandit_score
    probabilities = score_result.alts.map{|a| a.probability.round}
    assert_equal [0,0,6,94], probabilities
  end

  def test_scoring_with_no_performers
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      default :a
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
      default :a
      metrics :coolness
    end
    fake :abcd, :b=>[10,8]
    assert experiment(:abcd).score.alts.all? { |alt| alt.z_score.nan? }
    assert experiment(:abcd).score.alts.all? { |alt| alt.probability == 0 }
    assert experiment(:abcd).score.alts.all? { |alt| alt.difference.nil? }
    assert_equal 1, experiment(:abcd).score.best.id
    assert_nil experiment(:abcd).score.choice
    assert_includes [0,2,3], experiment(:abcd).score.base.id
    assert_equal 1, experiment(:abcd).score.least.id
  end

  def test_scoring_with_some_performers
    new_ab_test :abcd do
      alternatives :a, :b, :c, :d
      default :a
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
      default :a
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
      default :a
      metrics :coolness
    end
    # participating, conversions, rate, z-score
    # Control:      182 35 19.23% N/A
    # Treatment A:  180 45 25.00% 1.33
    # treatment B:  189 28 14.81% -1.13
    # treatment C:  188 61 32.45% 2.94
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
      default :a
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
      default :a
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
      default :a
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
      default :a
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
      default :a
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
      default :a
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
      default false
    end
    experiment(:simple).choose
    assert !experiment(:simple).active?
  end

  def test_completion_if_fails
    new_ab_test :simple do
      identify { rand }
      complete_if { fail "Testing complete_if raises exception" }
      metrics :coolness
      default false
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
      default false
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
      default false
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
      default false
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives[1], experiment(:quick).outcome
  end

  def test_completion_with_outcome
    new_ab_test :quick do
      metrics :coolness
      default false
    end
    experiment(:quick).complete!(1)
    assert_equal experiment(:quick).alternatives[1], experiment(:quick).outcome
  end

  def test_error_in_completion
    new_ab_test :quick do
      outcome_is { raise RuntimeError }
      metrics :coolness
      default false
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
      default false
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives.first, experiment(:quick).outcome
  end

  def test_outcome_is_returns_something_else
    new_ab_test :quick do
      outcome_is { "error" }
      metrics :coolness
      default false
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives.first, experiment(:quick).outcome
  end

  def test_outcome_is_fails
    new_ab_test :quick do
      outcome_is { fail "Testing outcome_is raising exception" }
      metrics :coolness
      default false
    end
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternatives.first, experiment(:quick).outcome
  end

  def test_outcome_choosing_best_alternative
    new_ab_test :quick do
      metrics :coolness
      default false
    end
    fake :quick, false=>[2,0], true=>10
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternative(true), experiment(:quick).outcome
  end

  def test_outcome_only_performing_alternative
    new_ab_test :quick do
      metrics :coolness
      default false
    end
    fake :quick, true=>2
    experiment(:quick).complete!
    assert_equal experiment(:quick).alternative(true), experiment(:quick).outcome
  end

  def test_outcome_choosing_equal_alternatives
    new_ab_test :quick do
      metrics :coolness
      default false
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
      default false
    end
    Vanity.playground.track! :coolness
    assert_equal 0, experiment(:abcd).alternatives.sum(&:conversions)
  end

  def test_no_collection_and_completion
    not_collecting!
    new_ab_test :quick do
      outcome_is { alternatives[1] }
      metrics :coolness
      default false
    end
    experiment(:quick).complete!
    assert_nil experiment(:quick).outcome
  end

  def test_no_collection_returns_default
    not_collecting!
    metric "Coolness"

    exp = new_ab_test :abcd do
      metrics :coolness
      alternatives :a, :b, :c, :d
      default :b
      identify { rand }
    end

    results = Set.new
    100.times do
      results << exp.choose.value
    end
    assert_equal results, [:b].to_set
  end

  def test_chooses_records_participants
    new_ab_test :simple do
      alternatives :a, :b, :c
      default :a
      metrics :coolness
    end
    experiment(:simple).chooses(:b)
    assert_equal experiment(:simple).alternatives[1].participants, 1
  end

  def test_chooses_moves_participant_to_new_alternative
    new_ab_test :simple do
      alternatives :a, :b, :c
      default :a
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
      default :a
      metrics :coolness
    end
    2.times { experiment(:simple).chooses(:b) }
    assert_equal experiment(:simple).alternatives[1].participants, 1
  end

  def test_chooses_records_participants_for_new_alternatives
    new_ab_test :simple do
      alternatives :a, :b, :c
      default :a
      metrics :coolness
    end
    experiment(:simple).chooses(:b)
    experiment(:simple).chooses(:c)
    assert_equal experiment(:simple).alternatives[2].participants, 1
  end

  def test_chooses_records_participants_given_a_valid_request
    new_ab_test :simple do
      alternatives :a, :b, :c
      default :a
      metrics :coolness
    end
    experiment(:simple).chooses(:a, dummy_request)
    assert_equal 1, experiment(:simple).alternatives[0].participants
  end

  def test_chooses_ignores_participants_given_an_invalid_request
    new_ab_test :simple do
      alternatives :a, :b, :c
      default :a
      metrics :coolness
    end
    request = dummy_request
    request.user_agent = "Googlebot/2.1 ( http://www.google.com/bot.html)"
    experiment(:simple).chooses(:a, request)
    assert_equal 0, experiment(:simple).alternatives[0].participants
  end

  def test_no_collection_and_chooses
    not_collecting!
    new_ab_test :simple do
      alternatives :a, :b, :c
      default :a
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
      default :a
      metrics :coolness
    end
    choice = experiment(:simple).choose.value
    assert [:a, :b, :c].include?(choice)
    assert_equal choice, experiment(:simple).choose.value
  end
  
  # -- Reset --
  
  def test_reset_clears_participants
    new_ab_test :simple do
      alternatives :a, :b, :c
      default :a
      metrics :coolness
    end
    experiment(:simple).chooses(:b)
    assert_equal experiment(:simple).alternatives[1].participants, 1
    experiment(:simple).reset
    assert_equal experiment(:simple).alternatives[1].participants, 0
  end
  
  def test_clears_outcome_and_completed_at
     new_ab_test :simple do
       alternatives :a, :b, :c
       default :a
       metrics :coolness	
     end	  	
    experiment(:simple).reset	  	
    assert_nil experiment(:simple).outcome  	
    assert_nil experiment(:simple).completed_at
  end
  
  # -- Pick Winner --
  
  def test_complete_with_argument_sets_outcome_and_completes
    new_ab_test :simple do
      alternatives :a, :b, :c
      default :a
      metrics :coolness
    end
    experiment(:simple).complete!(experiment(:simple).alternatives[1].id)
    assert_equal experiment(:simple).alternatives[1], experiment(:simple).outcome
    assert_not_nil experiment(:simple).completed_at
  end

  def test_reset_clears_participants
    new_ab_test :simple do
      alternatives :a, :b, :c
      default :a
      metrics :coolness
    end
    experiment(:simple).chooses(:b)
    assert_equal experiment(:simple).alternatives[1].participants, 1
    experiment(:simple).reset
    assert_equal experiment(:simple).alternatives[1].participants, 0
  end

  def test_clears_outcome_and_completed_at
    new_ab_test :simple do
      alternatives :a, :b, :c
      default :a
      metrics :coolness
    end
    experiment(:simple).reset
    assert_nil experiment(:simple).outcome
    assert_nil experiment(:simple).completed_at
  end


  # -- Helper methods --

  def fake(name, args)
    experiment(name).instance_eval { fake args }
  end

end
