module Vanity
  module Experiment

    # Base class that all experiment types are derived from.
    class Base

      class << self
        
        # Returns the type of this class as a symbol (e.g. AbTest becomes
        # ab_test).
        def type
          name.split("::").last.gsub(/([a-z])([A-Z])/) { "#{$1}_#{$2}" }.gsub(/([A-Z])([A-Z][a-z])/) { "#{$1}_#{$2}" }.downcase
        end

      end

      def initialize(playground, id, name, &block)
        @playground = playground
        @id, @name = id.to_sym, name
        @namespace = "#{@playground.namespace}:experiments:#{@id}"
        created = redis.get(key(:created_at)) || (redis.setnx(key(:created_at), Time.now.to_i) ; redis.get(key(:created_at))) 
        @created_at = Time.at(created.to_i)
        @identify_block = ->(context){ context.vanity_identity }
      end

      # Human readable experiment name, supplied during creation.
      attr_reader :name

      # Unique identifier, derived from name, e.g. "Green Button" become :green_button.
      attr_reader :id
      
      # Experiment creation timestamp.
      attr_reader :created_at
     
      # Sets or returns description. For example
      #   experiment :simple do
      #     description "Simple experiment"
      #   end
      #
      #   puts "Just defined: " + experiment(:simple).description
      def description(text = nil)
        @description = text if text
        @description
      end

      def report
        fail "Implement me"
      end
      
      # Called to save the experiment definition.
      def save #:nodoc:
      end

      # Call this method with no argument or block to return an identity.  Call
      # this method with a block to define how to obtain an identity for the
      # current experiment.
      #
      # For example, this experiment use the identity of the project associated
      # with the controller:
      #
      #   class ProjectController < ApplicationController
      #     before_filter :set_project
      #     attr_reader :project
      #
      #     . . .
      #   end
      #
      #   experiment "Project widget" do
      #     alternatives :small, :medium, :large
      #     identify do |controller|
      #       controller.project.id
      #     end
      #   end
      
      def identify(&block)
        if block_given?
          @identify_block = block
          self
        else
          @identify_block.call(Vanity.context) or fail "No identity found"
        end
      end

    protected

      # Returns key for this experiment, or with an argument, return a key
      # using the experiment as the namespace.  Examples:
      #   key => "vanity:experiments:green_button"
      #   key("participants") => "vanity:experiments:green_button:participants"
      def key(name = nil)
        name ? "#{@namespace}:#{name}" : @namespace
      end

      # Shortcut for Vanity.playground.redis
      def redis
        @playground.redis
      end
    end
  end
end

