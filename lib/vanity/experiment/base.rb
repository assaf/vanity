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
        @namespace = "#{@playground.namespace}:#{@id}"
        redis.setnx key(:created_at), Time.now.to_i
        @created_at = Time.at(redis[key(:created_at)].to_i)
        @identify_block = ->(context){ context.vanity_identity }
      end

      # Human readable experiment name, supplied during creation.
      attr_reader :name

      # Unique identifier, derived from name, e.g. "Green Button" become :green_button.
      attr_reader :id
      
      # Experiment creation timestamp.
      attr_reader :created_at

      # Experiment completion timestamp.
      attr_reader :completed_at

      # Returns the type of this class as a symbol (e.g. ab_test).
      def type
        self.class.type
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


      # -- Reporting --

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
      

      # -- Experiment completion --

      # Define experiment completion condition.  For example:
      #   complete_if do
      #     alternatives.all? { |alt| alt.participants >= 100 } &&
      #     alternatives.any? { |alt| alt.confidence >= 0.95 }
      #   end
      def complete_if(&block)
        raise ArgumentError, "Missing block" unless block
        raise "complete_if already called on this experiment" if @complete_block
        @complete_block = block
      end

      # Derived classes call this after state changes that may lead to
      # experiment completing.
      def check_completion!
        if @complete_block
          begin
            complete! if @complete_block.call
          rescue
            # TODO: logging
          end
        end
      end
      protected :check_completion!

      # Force experiment to complete.
      def complete!
        redis.setnx key(:completed_at), Time.now.to_i
        # TODO: logging
      end

      # Time stamp when experiment was completed.
      def completed_at
        time = redis[key(:completed_at)]
        time && Time.at(time.to_i)
      end
      
      # Returns true if experiment active, false if completed.
      def active?
        redis[key(:completed_at)].nil?
      end


      # -- Store/validate --

      # Returns key for this experiment, or with an argument, return a key
      # using the experiment as the namespace.  Examples:
      #   key => "vanity:experiments:green_button"
      #   key("participants") => "vanity:experiments:green_button:participants"
      def key(name = nil) #:nodoc:
        name ? "#{@namespace}:#{name}" : @namespace
      end

      # Shortcut for Vanity.playground.redis
      def redis #:nodoc:
        @playground.redis
      end
      
      # Called to save the experiment definition.
      def save #:nodoc:
      end

      # Reset experiment.
      def reset!
        @created_at = Time.now
        redis[key(:created_at)] = @created_at.to_i
        redis.del key(:completed_at)
      end

      # Get rid of all experiment data.
      def destroy
        redis.del key(:created_at)
        redis.del key(:completed_at)
      end

    end
  end
end

