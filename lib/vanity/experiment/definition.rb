module Vanity
  module Experiment
    # These methods are available from experiment definitions (files located in
    # the experiments directory, automatically loaded by Vanity). Use these
    # methods to define your experiments, for example:
    #   ab_test "New Banner" do
    #     alternatives :red, :green, :blue
    #     metrics :signup
    #   end
    module Definition

      attr_reader :playground

      # Defines a new experiment, given the experiment's name, type and
      # definition block.
      def define(name, type, options = nil, &block)
        fail "Experiment #{@experiment_id} already defined in playground" if playground.experiments[@experiment_id]
        klass = Experiment.const_get(type.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase })
        experiment = klass.new(playground, @experiment_id, name, options)
        experiment.instance_eval &block
        experiment.save
        playground.experiments[@experiment_id] = experiment
      end

      def new_binding(playground, id)
        @playground, @experiment_id = playground, id
        binding
      end

    end
  end
end