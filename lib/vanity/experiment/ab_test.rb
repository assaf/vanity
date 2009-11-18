module Vanity
  module Experiment

    # Experiment alternative.  See AbTest#alternatives and AbTest#score.
    class Alternative

      def initialize(experiment, id, value, participants, converted, conversions) #:nodoc:
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

      # Number of participants who converted on this alternative.
      attr_reader :converted

      # Number of conversions for this alternative (same participant may be counted more than once).
      attr_reader :conversions

      # Z-score for this alternative. Populated by AbTest#score.
      attr_accessor :z_score

      # Probability derived from z-score. Populated by AbTest#score.
      attr_accessor :probability
    
      # Difference from least performing alternative. Populated by AbTest#score.
      attr_accessor :difference

      # Conversion rate calculated as converted/participants, rounded to 3 places.
      def conversion_rate
        @rate ||= (participants > 0 ? (converted.to_f/participants.to_f).round(3) : 0.0)
      end

      def <=>(other) # sort by conversion rate
        conversion_rate <=> other.conversion_rate 
      end

      def ==(other)
        other && id == other.id && experiment == other.experiment
      end

      def to_s #:nodoc:
        name
      end

      def inspect #:nodoc:
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

      def initialize(*args) #:nodoc:
        super
        @alternatives = [false, true]
      end

      # -- Alternatives --

      # Call this method once to set alternative values for this experiment.
      # Require at least two values.  For example:
      #   ab_test "Background color" do
      #     alternatives "red", "blue", "orange"
      #   end
      # 
      # Call without arguments to obtain current list of alternatives.  For example:
      #   alts = experiment(:background_color).alternatives
      #   puts "#{alts.count} alternatives, with the colors: #{alts.map(&:value).join(", ")}"
      #
      # If you want to know how well each alternative is faring, use #score.
      def alternatives(*args)
        unless args.empty?
          @alternatives = args.clone
        end
        class << self
          alias :alternatives :_alternatives
        end
        alternatives
      end

      def _alternatives #:nodoc:
        alts = []
        @alternatives.each_with_index do |value, i|
          participants = redis.scard(key("alts:#{i}:participants")).to_i
          converted = redis.scard(key("alts:#{i}:converted")).to_i
          conversions = redis[key("alts:#{i}:conversions")].to_i
          alts << Alternative.new(self, i, value, participants, converted, conversions)
        end
        alts
      end

      # Returns an Alternative with the specified value.
      def alternative(value)
        if index = @alternatives.index(value)
          participants = redis.scard(key("alts:#{index}:participants")).to_i
          converted = redis.scard(key("alts:#{index}:converted")).to_i
          conversions = redis[key("alts:#{index}:conversions")].to_i
          Alternative.new(self, index, value, participants, converted, conversions)
        end
      end

      # Sets this test to two alternatives: false and true.
      def false_true
        alternatives false, true
      end
      alias true_false false_true

      # Chooses a value for this experiment.
      #
      # This method returns different values for different identity (see
      # #identify), and consistenly the same value for the same
      # expriment/identity pair.
      #
      # For example:
      #   color = experiment(:which_blue).choose
      def choose
        if active?
          identity = identify
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

      # Records a conversion.
      #
      # For example:
      #   experiment(:which_blue).conversion!
      def conversion!
        return unless active?
        identity = identify
        return if redis[key("participants:#{identity}:show")]
        index = alternative_for(identity)
        if redis.sismember(key("alts:#{index}:participants"), identity)
          redis.sadd key("alts:#{index}:converted"), identity
          redis.incr key("alts:#{index}:conversions")
        end
        check_completion!
      end

      
      # -- Testing --
     
      # Forces this experiment to use a particular alternative. Useful for
      # tests, e.g.
      #
      #   setup do
      #     experiment(:green_button).select(true)
      #   end
      #
      #   def test_shows_green_button
      #     . . .
      #   end
      #
      # Use nil to clear out selection:
      #   teardown do
      #     experiment(:green_button).select(nil)
      #   end
      def chooses(value)
        index = @alternatives.index(value)
        raise ArgumentError, "No alternative #{value.inspect} for #{name}" unless index
        identity = identify
        redis[key("participant:#{identity}:show")] = index
        self
      end

      # True if this alternative is currently showing (see #chooses).
      def showing?(alternative) #:nodoc:
        identity = identify
        index = redis[key("participant:#{identity}:show")]
        index && index.to_i == alternative.id
      end

      # Used for testing.
      def count(identity, value, *what) #:nodoc:
        index = @alternatives.index(value)
        raise ArgumentError, "No alternative #{value.inspect} for #{name}" unless index
        if what.empty? || what.include?(:participant)
          redis.sadd key("alts:#{index}:participants"), identity
        end
        if what.empty? || what.include?(:conversion)
          redis.sadd key("alts:#{index}:converted"), identity
          redis.incr key("alts:#{index}:conversions")
        end
        self
      end


      # -- Reporting --

      # Returns an object with the following methods:
      # [:alts]   List of Alternative populated with interesting statistics.
      # [:best]   Best performing alternative.
      # [:base]   Second best performing alternative.
      # [:least]  Least performing alternative (but more than zero conversion).
      # [:choice] Choice alterntive, either the outcome or best alternative.
      #
      # Alternatives returned by this method are populated with the following attributes:
      # [:z_score]      Z-score (relative to the base alternative).
      # [:probability]  Probability (z-score mapped to 0, 90, 95, 99 or 99.9%).
      # [:difference]   Difference from the least performant altenative.
      #
      # The choice alternative is set only if the probability is higher or
      # equal to the specified probability (default is 90%).
      def score(probability = 90)
        alts = alternatives
        # sort by conversion rate to find second best and 2nd best
        sorted = alts.sort_by(&:conversion_rate)
        base = sorted[-2]
        # calculate z-score
        pc = base.conversion_rate
        nc = base.participants
        alts.each do |alt|
          p = alt.conversion_rate
          n = alt.participants
          alt.z_score = (p - pc) / ((p * (1-p)/n) + (pc * (1-pc)/nc)).abs ** 0.5
          alt.probability = AbTest.probability(alt.z_score)
        end
        # difference is measured from least performant
        if least = sorted.find { |alt| alt.conversion_rate > 0 }
          alts.each do |alt|
            if alt.conversion_rate > least.conversion_rate
              alt.difference = (alt.conversion_rate - least.conversion_rate) / least.conversion_rate * 100
            end
          end
        end
        # best alternative is one with highest conversion rate (best shot).
        # choice alternative can only pick best if we have high probability (>90%).
        best = sorted.last if sorted.last.conversion_rate > 0.0
        choice = outcome ? alts[outcome.id] : (best && best.probability >= probability ? best : nil)
        Struct.new(:alts, :best, :base, :least, :choice).new(alts, best, base, least, choice)
      end

      # Use the score returned by #score to derive a conclusion.  Returns an
      # array of claims.
      def conclusion(score = score)
        claims = []
        # only interested in sorted alternatives with conversion
        sorted = score.alts.select { |alt| alt.conversion_rate > 0.0 }.sort_by(&:conversion_rate).reverse
        if sorted.size > 1
          # start with alternatives that have conversion, from best to worst,
          # then alternatives with no conversion.
          sorted |= score.alts
          # we want a result that's clearly better than 2nd best.
          best, second = sorted[0], sorted[1]
          if best.conversion_rate > second.conversion_rate
            diff = ((best.conversion_rate - second.conversion_rate) / second.conversion_rate * 100).round
            better = " (%d%% better than %s)" % [diff, second.name] if diff > 0
            claims << "The best choice is %s: it converted at %.1f%%%s." % [best.name, best.conversion_rate * 100, better]
            if best.probability >= 90
              claims << "With %d%% probability this result is statistically significant." % score.best.probability
            else
              claims << "This result is not statistically significant, suggest you continue this experiment."
            end
            sorted.delete best
          end
          sorted.each do |alt|
            if alt.conversion_rate > 0.0
              claims << "%s converted at %.1f%%." % [alt.name.gsub(/^o/, "O"), alt.conversion_rate * 100]
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
      # The default implementation looks for the best (highest conversion rate)
      # alternative.  If it's certain (95% or more) that this alternative is
      # better than the first alternative, it switches to that one.  If it has
      # no such certainty, it starts using the first alternative exclusively.
      #
      # The default implementation reads like this:
      #   outcome_is do
      #     highest = alternatives.sort.last
      #     highest.probability >= 95 ? highest ? alternatives.first
      #   end
      def outcome_is(&block)
        raise ArgumentError, "Missing block" unless block
        raise "outcome_is already called on this experiment" if @outcome_is
        @outcome_is = block
      end

      # Alternative chosen when this experiment was completed.
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

      def save
        fail "Experiment #{name} needs at least two alternatives" unless alternatives.count >= 2
        super
      end

      def reset!
        @alternatives.count.times do |i|
          redis.del key("alts:#{i}:participants")
          redis.del key("alts:#{i}:converted")
          redis.del key("alts:#{i}:conversions")
        end
        redis.del key(:outcome)
        super
      end

      def destroy
        reset
        super
      end

    private

      # Chooses an alternative for the identity and returns its index. This
      # method always returns the same alternative for a given experiment and
      # identity, and randomly distributed alternatives for each identity (in the
      # same experiment).
      def alternative_for(identity)
        Digest::MD5.hexdigest("#{name}/#{identity}").to_i(17) % @alternatives.count
      end

      begin
        a = 50.0
        # Returns array of [z-score, percentage]
        norm_dist = (0.0..3.1).step(0.01).map { |x| [x, a += 1 / Math.sqrt(2 * Math::PI) * Math::E ** (-x ** 2 / 2)] }
        # We're really only interested in 90%, 95%, 99% and 99.9%.
        Z_TO_PROBABILITY = [90, 95, 99, 99.9].map { |pct| [norm_dist.find { |x,a| a >= pct }.first, pct] }.reverse
      end

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
