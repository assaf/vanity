require "digest/md5"
require "vanity/experiment/alternative"
require "vanity/experiment/bayesian_bandit_score"

module Vanity
  module Experiment
    # The meat.
    class AbTest < Base
      class << self
      	# Convert z-score to probability.
      	def probability(score)
      	  score = score.abs
      	  probability = AbTest::Z_TO_PROBABILITY.find { |z,p| score >= z }
      	  probability ? probability.last : 0
      	end

      	def friendly_name
      	  "A/B Test"
      	end
      end

      DEFAULT_SCORE_METHOD = :z_score

      def initialize(*args)
        super
      	@score_method = DEFAULT_SCORE_METHOD
        @use_probabilities = nil
      end

      # -- Metric --

      # Tells A/B test which metric we're measuring, or returns metric in use.
      #
      # @example Define A/B test against coolness metric
      #   ab_test "Background color" do
      #     metrics :coolness
      #     alternatives "red", "blue", "orange"
      #   end
      # @example Find metric for A/B test
      #   puts "Measures: " + experiment(:background_color).metrics.map(&:name)
      def metrics(*args)
        @metrics = args.map { |id| @playground.metric(id) } unless args.empty?
        @metrics
      end

      # -- Alternatives --

      # Call this method once to set alternative values for this experiment
      # (requires at least two values).  Call without arguments to obtain
      # current list of alternatives.
      #
      # @example Define A/B test with three alternatives
      #   ab_test "Background color" do
      #     metrics :coolness
      #     alternatives "red", "blue", "orange"
      #   end
      #
      # @example Find out which alternatives this test uses
      #   alts = experiment(:background_color).alternatives
      #   puts "#{alts.count} alternatives, with the colors: #{alts.map(&:value).join(", ")}"
      def alternatives(*args)
        @alternatives = args.empty? ? [true, false] : args.clone
        class << self
          define_method :alternatives, instance_method(:_alternatives)
        end
        nil
      end

      def _alternatives
        alts = []
        @alternatives.each_with_index do |value, i|
          alts << Alternative.new(self, i, value)
        end
        alts
      end
      private :_alternatives

      # Returns an Alternative with the specified value.
      #
      # @example
      #   alternative(:red) == alternatives[0]
      #   alternative(:blue) == alternatives[2]
      def alternative(value)
        alternatives.find { |alt| alt.value == value }
      end

      # What method to use for calculating score.  Default is :ab_test, but can
      # also be set to :bayes_bandit_score to calculate probability of each
      # alternative being the best.
      #
      # @example Define A/B test which uses bayes_bandit_score in reporting
      # ab_test "noodle_test" do
      #   alternatives "spaghetti", "linguine"
      #   metrics :signup
      #   score_method :bayes_bandit_score
      # end
      def score_method(method=nil)
      	if method
      	  @score_method = method
      	end
      	@score_method
      end

      # Defines an A/B test with two alternatives: false and true.  This is the
      # default pair of alternatives, so just syntactic sugar for those who love
      # being explicit.
      #
      # @example
      #   ab_test "More bacon" do
      #     metrics :yummyness
      #     false_true
      #   end
      #
      def false_true
        alternatives false, true
      end
      alias true_false false_true

      # Chooses a value for this experiment.  You probably want to use the
      # Rails helper method ab_test instead.
      #
      # This method picks an alternative for the current identity and returns
      # the alternative's value.  It will consistently choose the same
      # alternative for the same identity, and randomly split alternatives
      # between different identities.
      #
      # @example
      #   color = experiment(:which_blue).choose
      def choose
        if @playground.collecting?
          if active?
            identity = identity()
            index = connection.ab_showing(@id, identity)
            unless index
              index = alternative_for(identity).to_i
              save_assignment(identity, index) unless @playground.using_js?
            end
          else
            index = connection.ab_get_outcome(@id) || alternative_for(identity)
          end
        else
          identity = identity()
          @showing ||= {}
          @showing[identity] ||= alternative_for(identity)
          index = @showing[identity]
        end
        alternatives[index.to_i]
      end

      # Returns fingerprint (hash) for given alternative.  Can be used to lookup
      # alternative for experiment without revealing what values are available
      # (e.g. choosing alternative from HTTP query parameter).
      def fingerprint(alternative)
        Digest::MD5.hexdigest("#{id}:#{alternative.id}")[-10,10]
      end


      # -- Testing --

      # Forces this experiment to use a particular alternative.  You'll want to
      # use this from your test cases to test for the different alternatives.
      #
      # @example Setup test to red button
      #   setup do
      #     experiment(:button_color).select(:red)
      #   end
      #
      #   def test_shows_red_button
      #     . . .
      #   end
      #
      # @example Use nil to clear selection
      #   teardown do
      #     experiment(:green_button).select(nil)
      #   end
      def chooses(value)
        if @playground.collecting?
          if value.nil?
            connection.ab_not_showing @id, identity
          else
            index = @alternatives.index(value)
            #add them to the experiment unless they are already in it
            unless index == connection.ab_showing(@id, identity)
              save_assignment(identity, index)
            end
            raise ArgumentError, "No alternative #{value.inspect} for #{name}" unless index
            if (connection.ab_showing(@id, identity) && connection.ab_showing(@id, identity) != index) ||
              alternative_for(identity) != index
              connection.ab_show @id, identity, index
            end
          end
        else
          @showing ||= {}
          @showing[identity] = value.nil? ? nil : @alternatives.index(value)
        end
        self
      end

      # True if this alternative is currently showing (see #chooses).
      def showing?(alternative)
        identity = identity()
        if @playground.collecting?
          (connection.ab_showing(@id, identity) || alternative_for(identity)) == alternative.id
        else
          @showing ||= {}
          @showing[identity] == alternative.id
        end
      end


      # -- Reporting --

      def calculate_score
      	if respond_to?(score_method)
      	  self.send(score_method)
      	else
      	  score
      	end
      end

      # Scores alternatives based on the current tracking data.  This method
      # returns a structure with the following attributes:
      # [:alts]   Ordered list of alternatives, populated with scoring info.
      # [:base]   Second best performing alternative.
      # [:least]  Least performing alternative (but more than zero conversion).
      # [:choice] Choice alternative, either the outcome or best alternative.
      #
      # Alternatives returned by this method are populated with the following
      # attributes:
      # [:z_score]      Z-score (relative to the base alternative).
      # [:probability]  Probability (z-score mapped to 0, 90, 95, 99 or 99.9%).
      # [:difference]   Difference from the least performant altenative.
      #
      # The choice alternative is set only if its probability is higher or
      # equal to the specified probability (default is 90%).
      def score(probability = 90)
        alts = alternatives
        # sort by conversion rate to find second best and 2nd best
        sorted = alts.sort_by(&:measure)
        base = sorted[-2]
        # calculate z-score
        pc = base.measure
        nc = base.participants
        alts.each do |alt|
          p = alt.measure
          n = alt.participants
          alt.z_score = (p - pc) / ((p * (1-p)/n) + (pc * (1-pc)/nc)).abs ** 0.5
          alt.probability = AbTest.probability(alt.z_score)
        end
        # difference is measured from least performant
        if least = sorted.find { |alt| alt.measure > 0 }
          alts.each do |alt|
            if alt.measure > least.measure
              alt.difference = (alt.measure - least.measure) / least.measure * 100
            end
          end
        end
        # best alternative is one with highest conversion rate (best shot).
        # choice alternative can only pick best if we have high probability (>90%).
        best = sorted.last if sorted.last.measure > 0.0
        choice = outcome ? alts[outcome.id] : (best && best.probability >= probability ? best : nil)
      	Struct.new(:alts, :best, :base, :least, :choice, :method).new(alts, best, base, least, choice, :score)
      end

      # Scores alternatives based on the current tracking data, using Bayesian
      # estimates of the best binomial bandit. Based on the R bandit package,
      # http://cran.r-project.org/web/packages/bandit, which is based on
      # Steven L. Scott, A modern Bayesian look at the multi-armed bandit,
      # Appl. Stochastic Models Bus. Ind. 2010; 26:639-658.
      # (http://www.economics.uci.edu/~ivan/asmb.874.pdf)
      #
      # This method returns a structure with the following attributes:
      # [:alts]   Ordered list of alternatives, populated with scoring info.
      # [:base]   Second best performing alternative.
      # [:least]  Least performing alternative (but more than zero conversion).
      # [:choice] Choice alternative, either the outcome or best alternative.
      #
      # Alternatives returned by this method are populated with the following
      # attributes:
      # [:probability]  Probability (probability this is the best alternative).
      # [:difference]   Difference from the least performant altenative.
      #
      # The choice alternative is set only if its probability is higher or
      # equal to the specified probability (default is 90%).
      def bayes_bandit_score(probability = 90)
      	begin
      	  require "backports/1.9.1/kernel/define_singleton_method" if RUBY_VERSION < "1.9"
      	  require "integration"
      	  require "rubystats"
      	rescue LoadError
      	  fail "to use bayes_bandit_score, install integration and rubystats gems"
      	end

      	begin
      	  require "gsl"
      	rescue LoadError
      	  warn "for better integration performance, install gsl gem"
      	end

      	BayesianBanditScore.new(alternatives, outcome).calculate!
      end

      # Use the result of #score or #bayes_bandit_score to derive a conclusion.  Returns an
      # array of claims.
      def conclusion(score = score)
        claims = []
        participants = score.alts.inject(0) { |t,alt| t + alt.participants }
        claims << case participants
          when 0 ; "There are no participants in this experiment yet."
          when 1 ; "There is one participant in this experiment."
          else ; "There are #{participants} participants in this experiment."
        end
        # only interested in sorted alternatives with conversion
        sorted = score.alts.select { |alt| alt.measure > 0.0 }.sort_by(&:measure).reverse
        if sorted.size > 1
          # start with alternatives that have conversion, from best to worst,
          # then alternatives with no conversion.
          sorted |= score.alts
          # we want a result that's clearly better than 2nd best.
          best, second = sorted[0], sorted[1]
          if best.measure > second.measure
      	    diff = ((best.measure - second.measure) / second.measure * 100).round
      	    better = " (%d%% better than %s)" % [diff, second.name] if diff > 0
      	    claims << "The best choice is %s: it converted at %.1f%%%s." % [best.name, best.measure * 100, better]
      	    if score.method == :bayes_bandit_score
      	      if best.probability >= 90
      		      claims << "With %d%% probability this result is the best." % score.best.probability
      	      else
      		      claims << "This result does not have strong confidence behind it, suggest you continue this experiment."
      	      end
      	    else
      	      if best.probability >= 90
      		      claims << "With %d%% probability this result is statistically significant." % score.best.probability
      	      else
      		      claims << "This result is not statistically significant, suggest you continue this experiment."
      	      end
      	    end
      	    sorted.delete best
      	  end
          sorted.each do |alt|
            if alt.measure > 0.0
              claims << "%s converted at %.1f%%." % [alt.name.gsub(/^o/, "O"), alt.measure * 100]
            else
              claims << "%s did not convert." % alt.name.gsub(/^o/, "O")
            end
          end
        else
          claims << "This experiment did not run long enough to find a clear winner."
        end
        claims << "#{score.choice.name.gsub(/^o/, "O")} selected as the best alternative." if score.choice
        claims
      end

      # -- Unequal probability assignments --

      def set_alternative_probabilities(alternative_probabilities)
        # create @use_probabilities as a function to go from [0,1] to outcome
        cumulative_probability = 0.0
        new_probabilities = alternative_probabilities.map {|am| [am, (cumulative_probability += am.probability)/100.0]}
        @use_probabilities = new_probabilities
      end

      # -- Experiment rebalancing --

      # Experiment rebalancing allows the app to automatically adjust the probabilities for each alternative; when one is performing better, it will increase its probability
      #  according to Bayesian one-armed bandit theory, in order to (eventually) maximize your overall conversions.

      # Sets or returns how often (as a function of number of people assigned) to rebalance. For example:
      #   ab_test "Simple" do
      #     rebalance_frequency 100
      #   end
      #
      #  puts "The experiment will automatically rebalance after every " + experiment(:simple).description + " users are assigned."
      def rebalance_frequency(rf = nil)
        if rf
          @assignments_since_rebalancing = 0
          @rebalance_frequency = rf
          rebalance!
        end
        @rebalance_frequency
      end

      # Force experiment to rebalance.
      def rebalance!
        return unless @playground.collecting?
        score_results = bayes_bandit_score
        if score_results.method == :bayes_bandit_score
          set_alternative_probabilities score_results.alts
        end
      end

      # -- Completion --

      # Defines how the experiment can choose the optimal outcome on completion.
      #
      # By default, Vanity will take the best alternative (highest conversion
      # rate) and use that as the outcome.  You experiment may have different
      # needs, maybe you want the least performing alternative, or factor cost
      # in the equation?
      #
      # The default implementation reads like this:
      #   outcome_is do
      #     a, b = alternatives
      #     # a is expensive, only choose a if it performs 2x better than b
      #     a.measure > b.measure * 2 ? a : b
      #   end
      def outcome_is(&block)
        raise ArgumentError, "Missing block" unless block
        raise "outcome_is already called on this experiment" if @outcome_is
        @outcome_is = block
      end

      # Alternative chosen when this experiment completed.
      def outcome
        return unless @playground.collecting?
        outcome = connection.ab_get_outcome(@id)
        outcome && _alternatives[outcome]
      end

      def complete!(outcome = nil)
        return unless @playground.collecting? && active?
        super

      	unless outcome
          if @outcome_is
            begin
              result = @outcome_is.call
              outcome = result.id if Alternative === result && result.experiment == self
            rescue
              warn "Error in AbTest#complete!: #{$!}"
            end
          else
            best = score.best
            outcome = best.id if best
          end
        end
        # TODO: logging
        connection.ab_set_outcome @id, outcome || 0
      end


      # -- Store/validate --

      def destroy
        connection.destroy_experiment @id
        super
      end

      def save
        true_false unless @alternatives
        fail "Experiment #{name} needs at least two alternatives" unless @alternatives.size >= 2
        super
        if @metrics.nil? || @metrics.empty?
          warn "Please use metrics method to explicitly state which metric you are measuring against."
          metric = @playground.metrics[id] ||= Vanity::Metric.new(@playground, name)
          @metrics = [metric]
        end
        @metrics.each do |metric|
          metric.hook &method(:track!)
        end
      end

      # Called when tracking associated metric.
      def track!(metric_id, timestamp, count, *args)
        return unless active?
        identity = identity() rescue nil
        if identity
          return if connection.ab_showing(@id, identity)
          index = alternative_for(identity)
          connection.ab_add_conversion @id, index, identity, count
          check_completion!
        end
      end

      # If you are not embarrassed by the first version of your product, you’ve
      # launched too late.
      #   -- Reid Hoffman, founder of LinkedIn

    protected

      # Used for testing.
      def fake(values)
        values.each do |value, (participants, conversions)|
          conversions ||= participants
          participants.times do |identity|
            index = @alternatives.index(value)
            raise ArgumentError, "No alternative #{value.inspect} for #{name}" unless index
            connection.ab_add_participant @id, index, "#{index}:#{identity}"
          end
          conversions.times do |identity|
            index = @alternatives.index(value)
            raise ArgumentError, "No alternative #{value.inspect} for #{name}" unless index
            connection.ab_add_conversion @id, index, "#{index}:#{identity}"
          end
        end
      end

      # Chooses an alternative for the identity and returns its index. This
      # method always returns the same alternative for a given experiment and
      # identity, and randomly distributed alternatives for each identity (in the
      # same experiment).
      def alternative_for(identity)
        if @use_probabilities
          existing_assignment = connection.ab_assigned @id, identity
          return existing_assignment if existing_assignment
          random_outcome = rand()
          @use_probabilities.each do |alternative, max_prob|
            return alternative.id if random_outcome < max_prob
          end
        end
        return Digest::MD5.hexdigest("#{name}/#{identity}").to_i(17) % @alternatives.size
      end

      # Saves the assignment of an alternative to a person and performs the necessary housekeeping.
      def save_assignment(identity, index)
        # if we have an on_assignment block, call it on new assignments
        if @on_assignment_block
          assignment = alternatives[index]
          if !connection.ab_seen @id, identity, assignment
            @on_assignment_block.call(Vanity.context, identity, assignment, self)
          end
        end
        # if we are rebalancing probabilities, keep track of how long it has been since we last rebalanced
        if @rebalance_frequency
          @assignments_since_rebalancing += 1
          if @assignments_since_rebalancing >= @rebalance_frequency
            @assignments_since_rebalancing = 0
            rebalance!
          end
        end
        connection.ab_add_participant @id, index, identity
        check_completion!
      end

      begin
        a = 50.0
        # Returns array of [z-score, percentage]
        norm_dist = []
        (0.0..3.1).step(0.01) { |x| norm_dist << [x, a += 1 / Math.sqrt(2 * Math::PI) * Math::E ** (-x ** 2 / 2)] }
        # We're really only interested in 90%, 95%, 99% and 99.9%.
        Z_TO_PROBABILITY = [90, 95, 99, 99.9].map { |pct| [norm_dist.find { |x,a| a >= pct }.first, pct] }.reverse
      end

    end


    module Definition
      # Define an A/B test with the given name.  For example:
      #   ab_test "New Banner" do
      #     alternatives :red, :green, :blue
      #   end
      def ab_test(name, &block)
        define name, :ab_test, &block
      end
    end

  end
end
