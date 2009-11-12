module Vanity
  module Experiment

    # Experiment alternative.  See AbTest#alternatives.
    class Alternative

      def initialize(experiment, id, value) #:nodoc:
        @experiment = experiment
        @id = id
        @name = "option #{(@id + 1)}"
        @value = value
      end

      # Alternative id, only unique for this experiment.
      attr_reader :id
     
      # Alternative name (option A, option B, etc).
      attr_reader :name

      # Alternative value.
      attr_reader :value

      # Number of participants who viewed this alternative.
      def participants
        redis.scard(key("participants")).to_i
      end

      # Number of participants who converted on this alternative.
      def converted
        redis.scard(key("converted")).to_i
      end

      # Number of conversions for this alternative (same participant may be counted more than once).
      def conversions
        redis[key("conversions")].to_i
      end

      # Conversion rate calculated as converted/participants.
      def conversion_rate
        c, p = converted.to_f, participants.to_f
        p > 0 ? c/p : 0.0
      end

      def <=>(other)
        conversion_rate <=> other.conversion_rate 
      end

      def participating!(identity)
        redis.sadd key("participants"), identity
      end

      def conversion!(identity)
        if redis.sismember(key("participants"), identity)
          redis.sadd key("converted"), identity
          redis.incr key("conversions")
        end
      end

      def destroy #:nodoc:
        redis.del key("participants")
        redis.del key("converted")
        redis.del key("conversions")
      end

      def to_s #:nodoc:
        name
      end

      def inspect #:nodoc:
        "#{name}: #{value} #{converted}/#{participants}"
      end

    protected

      def key(name)
        @experiment.key("alts:#{id}:#{name}")
      end

      def redis
        @experiment.redis
      end

      def base
        @base ||= @experiment.alternatives.first
      end

    end


    # The meat.
    class AbTest < Base
      class << self

        def confidence(score) #:nodoc:
          confidence = AbTest::Z_TO_CONFIDENCE.find { |z,p| score >= z }
          confidence ? confidence.last : 0
        end
      end

      def initialize(*args) #:nodoc:
        super
      end

      # -- Alternatives --

      # Call this method once to specify values for the A/B test.  At least two
      # values are required.
      #
      # Call without argument to previously defined alternatives (see Alternative).
      #
      # For example:
      #   experiment "Background color" do
      #     alternatives "red", "blue", "orange"
      #   end
      #
      #   alts = experiment(:background_color).alternatives
      #   puts "#{alts.count} alternatives, with the colors: #{alts.map(&:value).join(", ")}"
      def alternatives(*args)
        args = [false, true] if args.empty?
        @alternatives = []
        args.each_with_index do |arg, i|
          @alternatives << Alternative.new(self, i, arg)
        end
        class << self ; self ; end.send(:define_method, :alternatives) { @alternatives }
        alternatives
      end

      # Returns an Alternative with the specified value.
      def alternative(value)
        alternatives.find { |alt| alt.value == value }
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
          alt = alternative_for(identity)
          alt.participating! identity
          check_completion!
          alt.value
        elsif alternative = outcome
          alternative.value
        else
          alternatives.first.value
        end
      end

      # Records a conversion.
      #
      # For example:
      #   experiment(:which_blue).conversion!
      def conversion!
        if active?
          identity = identify
          alt = alternative_for(identity)
          alt.conversion! identity
          check_completion!
        end
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
        alternative = alternatives.find { |alt| alt.value == value }
        raise ArgumentError, "No alternative #{value.inspect} for #{name}" unless alternative
        Vanity.context.session[:vanity] ||= {}
        Vanity.context.session[:vanity][id] = alternative.id
      end


      # -- Reporting --

      # Returns an object with the following attributes:
      # [:alts]  List of alternatives as structures (see below).
      # [:best]  Best alternative.
      # [:base]  Second best alternative.
      # [:choice]  Choice alterntive, either selected outcome or :best.
      #
      # Each alternative is an object with the following attributes:
      # [:id]    Identifier.
      # [:conv]  Conversion rate (0.0 to 1.0).
      # [:pop]   Population size (participants).
      # [:z]     Z-score compared to base (above).
      # [:conf]  Confidence based on z-score (0, 90, 95, 99, 99.9).
      def score
        struct = Struct.new(:id, :conv, :pop, :z, :conf)
        alts = alternatives.map { |alt| struct.new(alt.id, alt.conversion_rate, alt.participants) }
        # sort by conversion rate to find second best and 2nd best
        sorted = alts.sort_by(&:conv)
        base = sorted[-2]
        # calculate z-score
        pc = base.conv
        nc = base.pop
        alts.each do |alt|
          p = alt.conv
          n = alt.pop
          alt.z = (p - pc) / ((p * (1-p)/n) + (pc * (1-pc)/nc)).abs ** 0.5
          alt.conf = AbTest.confidence(alt.z)
        end
        # chosen alternative. we pick only if we have confidence to back it up.
        best = sorted.last if sorted.last.conf > 0
        choice = outcome ? alts[outcome.id] : best
        Struct.new(:alts, :best, :base, :choice).new(alts, best, base, choice)
      end

      # Use the score returned by #score to derive a conclusion.  Returns an
      # array of claims.
      def conclusion(score = score)
        claims = []
        # find name form alt structure returned from score
        name = ->(alt){ alternatives[alt.id].name }
        # only interested in sorted alternatives with conversion
        sorted = score.alts.select { |alt| alt.conv > 0.0 }.sort_by(&:conv).reverse
        if sorted.size > 1
          # start with alternatives that have conversion, from best to worst,
          # then alternatives with no conversion.
          sorted |= score.alts
          # we want a result that's clearly better than 2nd best.
          best, second = sorted[0], sorted[1]
          if best.conv > second.conv
            claims << "The best choice is %s, it converted at %.1f%% (%d%% better than %s)." %
              [name[best], best.conv * 100, (best.conv - second.conv) / second.conv * 100, name[second]]
            if best.conf >= 90
              claims << "There is %d%% chance this result is statistically significant." % score.best.conf
            else
              claims << "This result is not statistically significant, suggest you continue this experiment."
            end
            sorted.delete best
          end
          sorted.each do |alt|
            if alt.conv > 0.0
              claims << "%s converted at %.1f%%." % [name[alt].capitalize, alt.conv * 100]
            else
              claims << "%s did not convert." % name[alt].capitalize
            end
          end
        else
          claims << "This experiment did not run long enough to find a clear winner."
        end
        claims << "#{name[score.choice].capitalize} selected as the best alternative." if score.choice
        claims
      end

      def humanize
        "A/B Test" 
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
      #     highest.confidence >= 95 ? highest ? alternatives.first
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

      def complete! #:nodoc:
        super
        if @outcome_is
          begin
            outcome = alternatives.find_index(@outcome_is.call)
          rescue
            # TODO: logging
          end
        end
        unless outcome
          best = score.best
          outcome = best.id if best
        end
        # TODO: logging
        redis.setnx key("outcome"), outcome
      end

      
      # -- Store/validate --

      def save #:nodoc:
        fail "Experiment #{name} needs at least two alternatives" unless alternatives.count >= 2
        super
      end

      def reset! #:nodoc:
        redis.del key(:outcome)
        alternatives.each(&:destroy)
        super
      end

      def destroy #:nodoc:
        redis.del key(:outcome)
        alternatives.each(&:destroy)
        super
      end

    private

      # Chooses an alternative for the identity and returns its index. This
      # method always returns the same alternative for a given experiment and
      # identity, and randomly distributed alternatives for each identity (in the
      # same experiment).
      def alternative_for(identity)
        session = Vanity.context.session[:vanity]
        index = session && session[id]
        index ||= Digest::MD5.hexdigest("#{name}/#{identity}").to_i(17) % alternatives.count
        alternatives[index]
      end

      begin
        a = 0
        # Returns array of [z-score, percentage]
        norm_dist = (-5.0..3.1).step(0.01).map { |x| [x, a += 1 / Math.sqrt(2 * Math::PI) * Math::E ** (-x ** 2 / 2)] }
        # We're really only interested in 90%, 95%, 99% and 99.9%.
        Z_TO_CONFIDENCE = [90, 95, 99, 99.9].map { |pct| [norm_dist.find { |x,a| a >= pct }.first, pct] }.reverse
      end

    end
  end
end
