module Vanity

  # Playground catalogs all your experiments, holds the Vanity configuration.
  #
  # @example
  #   Vanity.playground.logger = my_logger
  #   puts Vanity.playground.map(&:name)
  class Playground

    DEFAULTS = { :host=>"127.0.0.1", :port=>6379, :db=>0, :load_path=>"experiments" }

    # Created new Playground. Unless you need to, use the global Vanity.playground.
    def initialize
      @experiments = {}
      @metrics = {}
      @host, @port, @db, @load_path = DEFAULTS.values_at(:host, :port, :db, :load_path)
      @namespace = "vanity:#{Vanity::Version::MAJOR}"
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::ERROR
      @loading = []
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
    # use one of the definition methods (ab_test, measure, etc).
    def define(name, type, options = {}, &block)
      id = name.to_s.downcase.gsub(/\W/, "_").to_sym
      raise "Experiment #{id} already defined once" if @experiments[id]
      klass = Experiment.const_get(type.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase })
      experiment = klass.new(self, id, name, options)
      experiment.instance_eval &block
      experiment.save
      @experiments[id] = experiment
    end

    # Returns the experiment. You may not have guessed, but this method raises
    # an exception if it cannot load the experiment's definition.
    def experiment(name)
      id = name.to_s.downcase.gsub(/\W/, "_").to_sym
      warn "Deprecated: pleae call experiment method with experiment identifier (a Ruby symbol)" unless id == name
      @experiments[id] ||= Experiment::Base.load(self, @loading, File.expand_path(load_path), id)
    end

    # Returns list of all loaded experiments.
    def experiments
      Dir[File.join(load_path, "*.rb")].each do |file|
        id = File.basename(file).gsub(/.rb$/, "")
        experiment id
      end
      @experiments.values
    end

    # Reloads all experiments.
    def reload!
      @experiments.clear
      @metrics.clear
    end

    # Use this instance to access the Redis database.
    def redis
      redis = Redis.new(:host=>self.host, :port=>self.port, :db=>self.db,
                        :password=>self.password, :logger=>self.logger)
      class << self ; self ; end.send(:define_method, :redis) { redis }
      redis
    end

    # Returns a metric (creating one if doesn't already exist).
    #
    # @since 1.1.0
    def metric(id)
      id = id.to_sym
      @metrics[id] ||= Metric.load(self, @loading, File.expand_path("metrics", load_path), id)
    end

    # Returns hash of metrics (key is metric id).
    #
    # @since 1.1.0
    def metrics
      redis.keys("metrics:*:created_at").each do |key|
        metric key[/metrics:(.*):created_at/, 1]
      end
      @metrics
    end

    # Tracks an action associated with a metric.
    #
    # @example
    #   Vanity.playground.track! :uploaded_video
    #
    # @since 1.1.0
    def track!(id, count = 1)
      metric(id).track! count
    end
  end

  @playground = Playground.new
  class << self

    # Returns the playground instance.
    #
    # @see Vanity::Playground
    def playground
      @playground
    end

    # Returns the Vanity context.  For example, when using Rails this would be
    # the current controller, which can be used to get/set the vanity identity.
    def context
      Thread.current[:vanity_context]
    end

    # Sets the Vanity context.  For example, when using Rails this would be
    # set by the set_vanity_context before filter (via Vanity::Rails#use_vanity).
    def context=(context)
      Thread.current[:vanity_context] = context
    end

    # Path to template.
    def template(name)
      path = File.join(File.dirname(__FILE__), "templates/#{name}")
      path << ".erb" unless name["."]
      path
    end

  end
end


class Object

  # Use this method to access an experiment by name.
  #
  # @example
  #   puts experiment(:text_size).alternatives
  #
  # @see Vanity::Playground#experiment
  def experiment(name)
    Vanity.playground.experiment(name)
  end
end
