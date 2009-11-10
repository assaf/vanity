require "active_support"

module Vanity

  # Playground catalogs all your experiments. Example:
  #
  #   Vanity.playground.define :green_button do
  #     ... define my experiment ...
  #   end
  #
  #   Vanity.playground.experiment(:green_button)
  #
  # Of course there's a shortcut for all these methods and you probably
  # want to start with the shortcuts.
  class Playground

    # Created new Playground. Unless you need to, use the global Vanity.playground.
    def initialize(options = {})
      @namespace = (options[:namespace] || "vanity_#{Vanity::Version::MAJOR}").downcase.gsub(/\W/, "_")
      @redis = options[:redis] || Redis.new
      @experiments = {}
    end

    attr_reader :namespace, :redis #:nodoc:

    # Defines a new experiment. Generally, do not call this directly,
    # use #experiment instead.
    def define(name, options = nil, &block)
      id = name.to_s.downcase.gsub(/\W/, "_")
      raise "Experiment #{id} already defined once" if @experiments[id]
      options ||= {}
      type = options[:type] || :ab_test
      klass = Experiment.const_get(type.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase })
      experiment = klass.new(id, name)
      experiment.instance_eval &block
      experiment.save
      @experiments[id] = experiment
    end

    # Returns the named experiment. You may not have guessed, but this method
    # raises an exception if it cannot load the experiment's definition.
    #
    # Experiment names are always mapped by downcasing them and replacing
    # non-word characters with underscores, so "Green call to action" becomes
    # "green_call_to_action". You can also use a symbol if you feel like it.
    def experiment(name)
      id = name.to_s.downcase.gsub(/\W/, "_")
      unless @experiments.has_key?(id)
        require "experiments/#{id}"
      end
      @experiments[id] or fail LoadError, "Expected experiments/#{id}.rb to define experiment #{name}"
    end

  end

  @playground = Playground.new
  # Returns the playground instance.
  def self.playground
    @playground
  end

  # Returns the Vanity context.  For example, when using Rails this would be
  # the current controller, which can be used to get/set the vanity identity.
  def self.context
    Thread.current[:vanity_context]
  end

  # Sets the Vanity context.  For example, when using Rails this would be
  # set by the set_vanity_context before filter (via use_vanity).
  def self.context=(context)
    Thread.current[:vanity_context] = context
  end

end
