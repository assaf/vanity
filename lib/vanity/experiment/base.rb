require "vanity/experiment/definition"

module Vanity
  module Experiment
    # Base class that all experiment types are derived from.
    class Base
      class << self
        # Returns the type of this class as a symbol (e.g. AbTest becomes
        # ab_test).
        def type
          name.split("::").last.gsub(/([a-z])([A-Z])/) { "#{Regexp.last_match(1)}_#{Regexp.last_match(2)}" }.gsub(/([A-Z])([A-Z][a-z])/) { "#{Regexp.last_match(1)}_#{Regexp.last_match(2)}" }.downcase
        end

        # Playground uses this to load experiment definitions.
        def load(playground, stack, file)
          raise "Circular dependency detected: #{stack.join('=>')}=>#{file}" if stack.include?(file)

          source = File.read(file)
          stack.push file
          id = File.basename(file, ".rb").downcase.gsub(/\W/, "_").to_sym
          context = Object.new
          context.instance_eval do
            extend Definition
            experiment = eval(source, context.new_binding(playground, id), file) # rubocop:todo Security/Eval
            raise NameError.new("Expected #{file} to define experiment #{id}", id) unless playground.experiments[id]

            return experiment
          end
        rescue StandardError
          error = NameError.exception($!.message, id)
          error.set_backtrace $!.backtrace
          raise error
        ensure
          stack.pop
        end
      end

      def initialize(playground, id, name, options = nil)
        @playground = playground
        @id = id.to_sym
        @name = name
        @options = options || {}
        @identify_block = method(:default_identify)
        @on_assignment_block = nil
      end

      # Human readable experiment name (first argument you pass when creating a
      # new experiment).
      attr_reader :name
      alias to_s name

      # Unique identifier, derived from name experiment name, e.g. "Green
      # Button" becomes :green_button.
      attr_reader :id

      attr_reader :playground

      # Time stamp when experiment was created.
      def created_at
        @created_at ||= connection.get_experiment_created_at(@id)
      end

      # Returns the type of this experiment as a symbol (e.g. :ab_test).
      def type
        self.class.type
      end

      # Defines how we obtain an identity for the current experiment. Usually
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
        raise "Missing block" unless block

        @identify_block = block
      end

      # Defines any additional actions to take when a new assignment is made for the current experiment
      #
      # For example, if you want to use the rails default logger to log whenever an assignment is made:
      #   ab_test "Project widget" do
      #     alternatives :small, :medium, :large
      #     on_assignment do |controller, identity, assignment|
      #       controller.logger.info "made a split test assignment for #{experiment.name}: #{identity} => #{assignment}"
      #     end
      #   end
      def on_assignment(&block)
        raise "Missing block" unless block

        @on_assignment_block = block
      end

      # -- Reporting --

      # Sets or returns description. For example
      #   ab_test "Simple" do
      #     description "A simple A/B experiment"
      #   end
      #
      #   puts "Just defined: " + experiment(:simple).description
      def description(text = nil)
        @description = text if text
        @description if defined?(@description)
      end

      # -- Experiment completion --

      # Define experiment completion condition. For example:
      #   complete_if do
      #     !score(95).chosen.nil?
      #   end
      def complete_if(&block)
        raise ArgumentError, "Missing block" unless block
        raise "complete_if already called on this experiment" if defined?(@complete_block)

        @complete_block = block
      end

      # Force experiment to complete.
      # @param optional integer id of the alternative that is the decided
      # outcome of the experiment
      def complete!(_outcome = nil)
        @playground.logger.info "vanity: completed experiment #{id}"
        return unless @playground.collecting?

        connection.set_experiment_completed_at @id, Time.now
        @completed_at = connection.get_experiment_completed_at(@id)
      end

      # Time stamp when experiment was completed.
      def completed_at
        @completed_at ||= connection.get_experiment_completed_at(@id)
      end

      # Returns true if experiment active, false if completed.
      def active?
        !@playground.collecting? || !connection.is_experiment_completed?(@id)
      end

      # -- Store/validate --

      # Get rid of all experiment data.
      def destroy
        connection.destroy_experiment @id
        @created_at = @completed_at = nil
      end

      # Called by Playground to save the experiment definition.
      def save
        return unless @playground.collecting?

        connection.set_experiment_created_at @id, Time.now
      end

      # -- Filtering Particpants --

      # Define an experiment specific request filter.  For example:
      #
      #   reject do |request|
      #     true if Vanity.context.cookies["somecookie"]
      #   end
      #
      def reject(&block)
        raise "Missing block" unless block
        raise "filter already called on this experiment" if @request_filter_block

        @request_filter_block = block
      end

      protected

      def identity
        @identify_block.call(Vanity.context)
      end

      def default_identify(context)
        raise "No Vanity.context" unless context
        raise "Vanity.context does not respond to vanity_identity" unless context.respond_to?(:vanity_identity, true)

        context.send(:vanity_identity) or raise "Vanity.context.vanity_identity - no identity"
      end

      # Derived classes call this after state changes that may lead to
      # experiment completing.
      def check_completion!
        if defined?(@complete_block) && @complete_block # rubocop:todo Style/GuardClause
          begin
            complete! if @complete_block.call
          rescue StandardError => e
            Vanity.logger.warn("Error in Vanity::Experiment::Base: #{e}")
          end
        end
      end

      # Returns key for this experiment, or with an argument, return a key
      # using the experiment as the namespace. Examples:
      #   key => "vanity:experiments:green_button"
      #   key("participants") => "vanity:experiments:green_button:participants"
      def key(name = nil)
        "#{@id}:#{name}"
      end

      # Shortcut for Vanity.playground.connection
      def connection
        @playground.connection
      end
    end
  end

  class NoExperimentError < NameError
  end
end
