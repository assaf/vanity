module Vanity
  module Experiment

    # The meat.
    class AbTest < Base
      def initialize(*args) #:nodoc:
        super
        @alternatives = [true, false]
      end

      # Chooses a value for the given identity. This method returns different
      # values for different identities, with random distribution, and consistently
      # returns the same value for the same identity.
      def choice(identity)
        alt = alternative_for(identity)
        if redis.sadd key("participant_#{identity}:experiments"), name
          redis.incr key("alternative_#{alt}:participants")
        end
        @alternatives[alt]
      end

      # Makes a conversion by the given identity. Each identity is counted once.
      def converted(identity)
        alt = alternative_for(identity)
        if redis.sismember(key("participant_#{identity}:experiments"), name)
          redis.sadd key("alternative_#{alt}:conversions"), identity
        end
      end

      # Specifies alternative values for the A/B test. At least two values are required.
      # For example:
      #   experiment :background_color do
      #     alternatives "red", "blue", "orange"
      #   end
      def alternatives(*args)
        @alternatives = args unless args.empty?
        @alternatives
      end

      # True/false A/B test. For example:
      #   experiment :new_background do
      #     true_false
      #   end
      def true_false
        alternatives true, false
      end

      # Returns measurements for this experience: an hash with the key being the
      # alternative and the value being a hash of the participants and conversion counts.
      # For example:
      #   { :red=>{:participants=>15, :conversions=>5},
      #     :blue=>{:participants=>12, :conversions=>8} }
      def measure
        (0...@alternatives.count).inject({}) { |h,alt| h.update(@alternatives[alt] => {
          participants: redis.get(key("alternative_#{alt}:participants")).to_i,
          conversions: redis.scard(key("alternative_#{alt}:conversions"))
        }) }
      end

      def report
        results = measure
        alts = (0...@alternatives.count).map { |i|
          alt = @alternatives[i]
          "<dt>Option #{(65 + i).chr}</dt><dd><code>#{CGI.escape_html @alternatives[i].inspect}</code> viewed #{results[alt][:participants]} times, converted #{results[alt][:conversions]}<dd>"
        }
        %{<dl class="data">#{alts.join}</dl>}
      end

      def humanize
        "A/B Test" 
      end

      def save #:nodoc:
        fail "Experiment #{name} needs at least two alternatives" unless @alternatives && @alternatives.size >= 2
        super
      end

    private

      # Chooses an alternative for the identity and returns its index. This method
      # always returns the same choice a given identity and experiment, and randomly
      # distributes results between different identities/experiments.
      def alternative_for(identity)
        Digest::MD5.hexdigest("#{name}/#{identity}").to_i(16) % @alternatives.count
      end

    end
  end
end

