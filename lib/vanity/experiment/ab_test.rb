require "digest/md5"

module Vanity
  module Experiment

    # One of several alternatives in an A/B test (see AbTest#alternatives).
    class Alternative

      def initialize(experiment, id, value, participants, converted, conversions)
        @experiment = experiment
        @id = id
        @name = "option #{(@id + 65).chr}"
        @value = value
        @participants, @converted, @conversions = participants, converted, conversions
      end

      # Alternative id, only unique for this experiment.
      attr_reader :id
     
      # Alternative name (option A, option B, etc).
      attr_reader :name

      # Alternative value.
      attr_reader :value

      # Experiment this alternative belongs to.
      attr_reader :experiment

      # Number of participants who viewed this alternative.
      attr_reader :participants

      # Number of participants who converted on this alternative (a participant is counted only once).
      attr_reader :converted

      # Number of conversions for this alternative (same participant may be counted more than once).
      attr_reader :conversions

      # Z-score for this alternative, related to 2nd-best performing alternative. Populated by AbTest#score.
      attr_accessor :z_score

      # Probability derived from z-score. Populated by AbTest#score.
      attr_accessor :probability
    
      # Difference from least performing alternative. Populated by AbTest#score.
      attr_accessor :difference

      # Conversion rate calculated as converted/participants, rounded to 3 places.
      def conversion_rate
        @conversion_rate ||= (participants > 0 ? (converted.to_f/participants.to_f * 1000).round / 1000.0 : 0.0)
      end

      # The measure we use to order (sort) alternatives and decide which one is better (by calculating z-score).
      # Defaults to conversion rate.
      def measure
        conversion_rate
      end

      def <=>(other)
        measure <=> other.measure 
      end

      def ==(other)
        other && id == other.id && experiment == other.experiment
      end

      def to_s
        name
      end

      def inspect
        "#{name}: #{value} #{converted}/#{participants}"
      end

    end


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

      def initialize(*args)
        super
        @alternatives = [false, true]
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
        unless args.empty?
          @alternatives = args.clone
        end
        class << self
          define_method :alternatives, instance_method(:_alternatives)
        end
        alternatives
      end

      def _alternatives
        alts = []
        @alternatives.each_with_index do |value, i|
          participants = redis.scard(key("alts:#{i}:participants")).to_i
          converted = redis.scard(key("alts:#{i}:converted")).to_i
          conversions = redis[key("alts:#{i}:conversions")].to_i
          alts << Alternative.new(self, i, value, participants, converted, conversions)
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
        if active?
          identity = identity()
          index = redis[key("participant:#{identity}:show")]
          unless index
            index = alternative_for(identity)
            redis.sadd key("alts:#{index}:participants"), identity
            check_completion!
          end
        else
          index = redis[key("outcome")] || alternative_for(identify)
        end
        @alternatives[index.to_i]
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
        if value.nil?
          redis.del key("participant:#{identity}:show")
        else
          index = @alternatives.index(value)
          raise ArgumentError, "No alternative #{value.inspect} for #{name}" unless index
          redis[key("participant:#{identity}:show")] = index
        end
        self
      end

      # True if this alternative is currently showing (see #chooses).
      def showing?(alternative)
        identity = identity()
        index = redis[key("participant:#{identity}:show")]
        index && index.to_i == alternative.id
      end


      # -- Reporting --

      # Scores alternatives based on the current tracking data.  This method
      # returns a structure with the following attributes:
      # [:alts]   Ordered list of alternatives, populated with scoring info.
      # [:base]   Second best performing alternative.
      # [:least]  Least performing alternative (but more than zero conversion).
      # [:choice] Choice alterntive, either the outcome or best alternative.
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
        Struct.new(:alts, :best, :base, :least, :choice).new(alts, best, base, least, choice)
      end

      # Use the result of #score to derive a conclusion.  Returns an
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
            if best.probability >= 90
              claims << "With %d%% probability this result is statistically significant." % score.best.probability
            else
              claims << "This result is not statistically significant, suggest you continue this experiment."
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
        outcome = redis[key("outcome")]
        outcome && alternatives[outcome.to_i]
      end

      def complete!
        return unless active?
        super
        if @outcome_is
          begin
            result = @outcome_is.call
            outcome = result.id if result && result.experiment == self
          rescue
            # TODO: logging
          end
        else
          best = score.best
          outcome = best.id if best
        end
        # TODO: logging
        redis.setnx key("outcome"), outcome || 0
      end

      
      # -- Store/validate --

      def destroy
        @alternatives.size.times do |i|
          redis.del key("alts:#{i}:participants")
          redis.del key("alts:#{i}:converted")
          redis.del key("alts:#{i}:conversions")
        end
        redis.del key(:outcome)
        super
      end

      def save
        fail "Experiment #{name} needs at least two alternatives" unless alternatives.size >= 2
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
          return if redis[key("participants:#{identity}:show")]
          index = alternative_for(identity)
          redis.sadd key("alts:#{index}:converted"), identity if redis.sismember(key("alts:#{index}:participants"), identity)
          redis.incrby key("alts:#{index}:conversions"), count
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
            redis.sadd key("alts:#{index}:participants"), identity
          end
          conversions.times do |identity|
            index = @alternatives.index(value)
            raise ArgumentError, "No alternative #{value.inspect} for #{name}" unless index
            redis.sadd key("alts:#{index}:converted"), identity
            redis.incr key("alts:#{index}:conversions")
          end
        end
      end

      # Chooses an alternative for the identity and returns its index. This
      # method always returns the same alternative for a given experiment and
      # identity, and randomly distributed alternatives for each identity (in the
      # same experiment).
      def alternative_for(identity)
        Digest::MD5.hexdigest("#{name}/#{identity}").to_i(17) % @alternatives.size
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
