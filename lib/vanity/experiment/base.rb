module Vanity
  module Experiment

    # Base class that all experiment types are derived from.
    class Base

      class << self
        # Type is a symbol derived from class name (e.g. AbTest becomes ab_test).
        def type
          name.split("::").last.gsub(/([a-z])([A-Z])/) { "#{$1}_#{$2}" }.gsub(/([A-Z])([A-Z][a-z])/) { "#{$1}_#{$2}" }.downcase
        end
      end

      def initialize(id, name, &block)
        @id, @name = id.to_sym, name
        @namespace = "#{Vanity.playground.namespace}:experiments:#{@id}"
        created = redis.get(key(:created_at)) || (redis.setnx(key(:created_at), Time.now.to_i) ; redis.get(key(:created_at))) 
        @created_at = Time.at(created.to_i)
      end

      # Human readable experiment name, supplied during creation.
      attr_reader :name

      # Unique identifier, derived from name, e.g. "Green Button" become :green_button.
      attr_reader :id
      
      # Time stamp when experiment first created in database.
      attr_reader :created_at
     
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

      def type
        self.class.name.split("::").last.gsub(/([a-z])([A-Z])/) { "#{$1}_#{$2}" }.gsub(/([A-Z])([A-Z][a-z])/) { "#{$1}_#{$2}" }.downcase
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

