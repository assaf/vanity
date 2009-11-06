module Vanity
  module Experiment

    # Base class that all experiment types are derived from.
    class Base
      def initialize(name, &block)
        @name = name.to_s
        @namespace = "#{Vanity.playground.namespace}:experiments:#{name.downcase.gsub(/\W/, "_")}"
        created = redis.get(key(:created_at)) || (redis.setnx(key(:created_at), Time.now.to_i) ; redis.get(key(:created_at))) 
        @created_at = Time.at(created.to_i)
      end

      attr_reader :name, :created_at
     
      # Sets of returs description. For example
      #   experiment :simple do
      #     description "Simple experiment"
      #   end
      #   puts "Just defined: " + experiment(:simple).description
      def description(text = nil)
        @description = text if text
        @description
      end

      # Called to save the experiment definition.
      def save #:nodoc:
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

