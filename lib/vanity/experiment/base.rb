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

      def initialize(playground, id, name, options, &block)
        @playground = playground
        @id, @name = id.to_sym, name
        @options = options || {}
        @namespace = "#{@playground.namespace}:#{@id}"
        @identify_block = ->(context){ context.vanity_identity }
      end

      # Human readable experiment name (first argument you pass when creating a
      # new experiment).
      attr_reader :name

      # Unique identifier, derived from name experiment name, e.g. "Green
      # Button" becomes :green_button.
      attr_reader :id

      # Time stamp when experiment was created.
      attr_reader :created_at

      # Time stamp when experiment was completed.
      attr_reader :completed_at

      # Returns the type of this experiment as a symbol (e.g. :ab_test).
      def type
        self.class.type
      end
     
      # Defines how we obtain an identity for the current experiment.  Usually
      # Vanity gets the identity form a session object (see use_vanity), but
      # there are cases where you want a particular experiment to use a
      # different identity.
      #
      # For example, if all your experiments use current_user and you need one
      # experiment to use the current project:
      #   ab_test "Project widget" do
      #     alternatives :small, :medium, :large
      #     identify do |controller|
      #       controller.project.id
      #     end
      #   end
      def identify(&block)
        @identify_block = block
      end

      def identity
        @identify_block.call(Vanity.context) or fail "No identity found"
      end
      protected :identity


      # -- Reporting --

      # Sets or returns description. For example
      #   ab_test "Simple" do
      #     description "A simple A/B experiment"
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
      #     !score(95).chosen.nil?
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

      # Get rid of all experiment data.
      def destroy
        redis.del key(:created_at)
        redis.del key(:completed_at)
      end

      # Called by Playground to save the experiment definition.
      def save
        redis.setnx key(:created_at), Time.now.to_i
        @created_at = Time.at(redis[key(:created_at)].to_i)
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

