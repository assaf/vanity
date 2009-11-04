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
    def define(name, options = {}, &block)
      name = name.to_s.downcase.gsub(/\W/, "_")
      raise "Experiment #{name} already defined once" if @experiments[name]
      yaml = redis.get("#{namespace}:experiments:#{name}")
      if yaml
        experiment = YAML.load(yaml)
      else
        experiment = Experiment::Base.new(name)
      end
      experiment.instance_eval &block
      experiment.save
      @experiments[name] = experiment
    end

    # Returns the named experiment. You may not have guessed, but this method
    # raises an exception if it cannot load the experiment's definition.
    #
    # Experiment names are always mapped by downcasing them and replacing
    # non-word characters with underscores, so "Green call to action" becomes
    # "green_call_to_action". You can also use a symbol if you feel like it.
    def experiment(name)
      name = name.to_s.downcase.gsub(/\W/, "_")
      unless @experiments.has_key?(name)
        require "experiments/#{name}"
      end
      @experiments[name] or fail LoadError, "Expected experiments/#{name}.rb to define experiment #{name}"
    end

  end

  @playground = Playground.new
  # Returns the playground instance.
  def self.playground
    @playground
  end

  # Returns an identity value. If you cannot afford an identity (see #identity=),
  # one will be assigned to you.
  def self.identity
    @identity ||= OpenSSL::Random.random_bytes(16).unpack("H*")[0]
  end

  # Sets the identity value. Generally, identity is associated with users and allows
  # you to present the same options consistently, particularly useful for A/B testing.
  # You'll want all users exposed to option A to keep seeing option A for the duration
  # of the experiment.
  #
  # Typically, you'll do something like this in ApplicationController:
  #   def set_vanity_identity
  #     if current_user
  #       Vanity.identity = current_user.id
  #     else
  #       Vanity.identity = cookies[:vanity_id]
  #       cookies[:vanity_id] = { value: Vanity.identity, expires: 1.month.from_now }
  #     end
  #   end
  def self.identity=(id)
    @identity = id
  end

end
