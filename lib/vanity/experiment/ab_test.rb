module Vanity
  module Experiment

    # Experiment alternative.  See AbTest#alternatives.
    class Alternative

      def initialize(experiment, id, value) #:nodoc:
        @experiment = experiment
        @id = id
        @value = value
      end

      # Alternative id, only unique for this experiment.
      attr_reader :id
     
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
        redis.get(key("conversions")).to_i
      end

      # Conversion rate calculated as converted/participants.
      def conversion_rate
        converted.to_f / participants.to_f
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

      # Z-score this alternativet related to the base alternative.  This
      # alternative is better than base if it receives a positive z-score,
      # worse if z-score is negative.  Call #confident if you need confidence
      # level (percentage).
      def z_score
        return 0 if base == self
        pc = base.conversion_rate
        nc = base.participants
        p = conversion_rate
        n = participants
        (p - pc) / Math.sqrt((p * (1-p)/n) + (pc * (1-pc)/nc))
      end

      # How confident are we in this alternative being an improvement over the
      # base alternative.  Returns 0, 90, 95, 99 or 99.9 (percentage).
      def confidence
        score = z_score
        confidence = AbTest::Z_TO_CONFIDENCE.find { |z,p| score >= z }
        confidence ? confidence.last : 0
      end

      def destroy #:nodoc:
        redis.del key("participants")
        redis.del key("converted")
        redis.del key("conversions")
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

      def report
        alts = alternatives.map { |alt|
          "<dt>Option #{(65 + alt.id).chr}</dt><dd><code>#{CGI.escape_html alt.value.inspect}</code> viewed #{alt.participants} times, converted #{alt.conversions}, rate #{alt.conversion_rate}, z_score #{alt.z_score}, confidence #{alt.confidence}<dd>"
        }
        %{<dl class="data">#{alts.join}</dl>}
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
        outcome = redis.get(key("outcome"))
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
          highest = alternatives.sort.last rescue nil
          outcome = highest && highest.confidence >= 95 ? highest.id : 0
        end
        # TODO: logging
        redis.setnx key("outcome"), outcome
      end

      
      # -- Store/validate --

      def save #:nodoc:
        fail "Experiment #{name} needs at least two alternatives" unless alternatives.count >= 2
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
