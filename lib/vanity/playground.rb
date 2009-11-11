require "active_support"

module Vanity

  # Vanity.playground.configuration
  class Configuration
  end

  # Playground catalogs all your experiments, holds the Vanity configuration.
  # For example:
  #   Vanity.playground.logger = my_logger
  #   puts Vanity.playground.map(&:name)
  class Playground

    # Created new Playground. Unless you need to, use the global Vanity.playground.
    def initialize
      @experiments = {}
      @host, @port, @db = "127.0.0.1", 6379, 0
      @namespace = "vanity:#{Vanity::Version::MAJOR}"
      @load_path = "experiments"
    end
    
    # Redis host name.  Default is 127.0.0.1
    attr_accessor :host

    # Redis port number.  Default is 6379.
    attr_accessor :port

    # Redis database number. Default is 0.
    attr_accessor :db

    # Redis database password.
    attr_accessor :password

    # Namespace for database keys.  Default is vanity:n, where n is the major release number, e.g. vanity:1 for 1.0.3.
    attr_accessor :namespace

    # Path to load experiment files from.
    attr_accessor :load_path

    # Logger.
    attr_accessor :logger

    # Defines a new experiment. Generally, do not call this directly,
    # use #experiment instead.
    def define(name, options = nil, &block)
      id = name.to_s.downcase.gsub(/\W/, "_")
      raise "Experiment #{id} already defined once" if @experiments[id]
      options ||= {}
      type = options[:type] || :ab_test
      klass = Experiment.const_get(type.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase })
      experiment = klass.new(self, id, name)
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
        require File.join(load_path, id)
      end
      @experiments[id] or fail LoadError, "Expected experiments/#{id}.rb to define experiment #{name}"
    end

    # Returns list of all loaded experiments.
    def experiments
      Dir[File.join(load_path, "*.rb")].each do |file|
        require file
      end
      @experiments.values
    end

    # Use this instance to access the Redis database.
    def redis
      redis = Redis.new(host: self.host, port: self.port, db: self.db,
                        password: self.password, logger: self.logger)
      class << self ; self ; end.send(:define_method, :redis) { redis }
      redis
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

class Object

  # Use this method to define or access an experiment.
  # 
  # To define an experiment, call with a name, options and a block.  For
  # example:
  #   experiment "Text size" do
  #     alternatives :small, :medium, :large
  #   end
  #
  #   puts experiment(:text_size).alternatives
  def experiment(name, options = nil, &block)
    if block
      Vanity.playground.define(name, options, &block)
    else
      Vanity.playground.experiment(name)
    end
  end
end
