require "active_support"

module Vanity

  # Playground catalogs all your experiments.  Use it to configure Vanity, for
  # example:
  #   Vanity.playground.config = "redis-server.local:6379"
  #   Vanity.plauground.config[:logger] = my_logger
  
  class Playground

    # Created new Playground. Unless you need to, use the global Vanity.playground.
    def initialize
      @experiments = {}
      @config = {}
    end

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
        require "experiments/#{id}"
      end
      @experiments[id] or fail LoadError, "Expected experiments/#{id}.rb to define experiment #{name}"
    end

    # Returns the configuration hash. For example:
    #   Vanity.playground.config[:logger] = my_logger
    def config
      @config
    end

    # Sets the configuration.  Value can be one of:
    # [Hash] Configuration options
    # [String] Redis host and port (e.g. "localhost:6379")
    # [nil] Clear out all configuration options.
    #
    # Configuration options include:
    # [host] Redis server host (defaults to 127.0.0.1)
    # [port] Redis server port (defaults to 6379)
    # [db] Redis database (defaults to 0)
    # [password] Password to use when accessing Redis database
    # [logger] Logger to use
    def config=(value)
      case value
      when String
        host, port = value.split(":")
        @config = { host: host, port: port }
      when Hash
        @config = value
      when nil
        @config = {}
      end
    end

    # Use this instance to access the Redis database.
    def redis
      redis = Redis.new(redis_config)
      class << self ; self ; end.send(:define_method, :redis) { redis }
      redis
    end

    # Use this namespace for all Redis keys.
    def namespace
      namespace = (config[:namespace] || "vanity_#{Vanity::Version::MAJOR}").downcase.gsub(/\W/, "_")
      class << self ; self ; end.send(:define_method, :namespace) { namespace }
      namespace
    end

  protected

    def redis_config
      { host: config[:host], port: config[:port], db: config[:db], password: config[:password] }
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
