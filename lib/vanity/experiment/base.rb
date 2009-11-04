module Vanity
  module Experiment

    # Base class that all experiment types are derived from.
    class Base
      def initialize(name, &block)
        @name = name.to_s
        @namespace = "#{Vanity.playground.namespace}:experiments:#{name.downcase.gsub(/\W/, "_")}"
      end

      attr_reader :name

      # Called to save the experiment definition.
      def save #:nodoc:
        redis.set key, to_yaml
      end

    protected

      # Returns key for this experiment or with additional name, e.g.
      #   key => "vanity:experiments:green_button"
      #   key("participants") => "vanity:experiments:green_button:participants"
      def key(name = nil)
        name ? "#{@namespace}:#{name}" : @namespace
      end

      # Shortcut for Vanity.playground.redis
      def redis
        Vanity.playground.redis
      end
    end
  end
end

