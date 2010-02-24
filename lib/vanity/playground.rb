module Vanity

  # Playground catalogs all your experiments, holds the Vanity configuration.
  #
  # @example
  #   Vanity.playground.logger = my_logger
  #   puts Vanity.playground.map(&:name)
  class Playground

    DEFAULTS = {
      :connection=>"localhost:6379",
      :load_path=>"experiments",
      :namespace=>"vanity:#{Vanity::Version::MAJOR}"
    }

    # Created new Playground. Unless you need to, use the global
    # Vanity.playground.
    #
    # First argument is connection specification (see #redis=), last argument is
    # a set of options, both are optional.  Supported options are:
    # - connection -- Connection specification
    # - namespace -- Namespace to use
    # - load_path -- Path to load experiments/metrics from
    # - logger -- Logger to use
    def initialize(*args)
      options = args.pop if Hash === args.last
      @options = DEFAULTS.merge(options || {})
      if @options.values_at(:host, :port, :db).any?
        warn "Deprecated: please specify Redis connection as single argument (\"host:port\")"
        @connection_spec = "#{@options[:host]}:#{@options[:port]}:#{@options[:db]}"
      elsif @options[:redis]
        @redis = @options[:redis]
      else
        @connection_spec = args.shift || @options[:connection]
      end

      @namespace = @options[:namespace] || DEFAULTS[:namespace]
      @load_path = @options[:load_path] || DEFAULTS[:load_path]
      @logger = @options[:logger]
      unless @logger
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::ERROR
      end
      @loading = []
    end
   
    # Deprecated. Use redis.server instead.
    attr_accessor :host, :port, :db, :password, :namespace

    # Path to load experiment files from.
    attr_accessor :load_path

    # Logger.
    attr_accessor :logger

    # Defines a new experiment. Generally, do not call this directly,
    # use one of the definition methods (ab_test, measure, etc).
    #
    # @see Vanity::Experiment
    def define(name, type, options = {}, &block)
      warn "Deprecated: if you need this functionality let's make a better API"
      id = name.to_s.downcase.gsub(/\W/, "_").to_sym
      raise "Experiment #{id} already defined once" if experiments[id]
      klass = Experiment.const_get(type.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase })
      experiment = klass.new(self, id, name, options)
      experiment.instance_eval &block
      experiment.save
      experiments[id] = experiment
    end

    # Returns the experiment. You may not have guessed, but this method raises
    # an exception if it cannot load the experiment's definition.
    #
    # @see Vanity::Experiment
    def experiment(name)
      id = name.to_s.downcase.gsub(/\W/, "_").to_sym
      warn "Deprecated: pleae call experiment method with experiment identifier (a Ruby symbol)" unless id == name
      experiments[id.to_sym] or raise NameError, "No experiment #{id}"
    end

    # Returns hash of experiments (key is experiment id).
    #
    # @see Vanity::Experiment
    def experiments
      unless @experiments
        @experiments = {}
        @logger.info "Vanity: loading experiments from #{load_path}"
        Dir[File.join(load_path, "*.rb")].each do |file|
          Experiment::Base.load self, @loading, file
        end
      end
      @experiments
    end

    # Reloads all metrics and experiments.  Rails calls this for each request in
    # development mode.
    def reload!
      @experiments = nil
      @metrics = nil
      load!
    end

    # Loads all metrics and experiments.  Rails calls this during
    # initialization.
    def load!
      experiments
      metrics
    end

    # Returns a metric (raises NameError if no metric with that identifier).
    #
    # @see Vanity::Metric
    # @since 1.1.0
    def metric(id)
      metrics[id.to_sym] or raise NameError, "No metric #{id}"
    end

    # Returns hash of metrics (key is metric id).
    #
    # @see Vanity::Metric
    # @since 1.1.0
    def metrics
      unless @metrics
        @metrics = {}
        @logger.info "Vanity: loading metrics from #{load_path}/metrics"
        Dir[File.join(load_path, "metrics/*.rb")].each do |file|
          Metric.load self, @loading, file
        end
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


    # -- Connection management --
   
    # Tells the playground where to find Redis.  Accepts one of the following:
    # - "hostname:port"
    # - ":port"
    # - "hostname:port:db"
    # - Instance of Redis connection. 
    def redis=(spec_or_connection)
      case spec_or_connection
      when String
        @connection_spec = spec_or_connection
        host, port, db = spec_or_connection.split(':').map { |x| x unless x.empty? }
        @redis = Redis.new(:host=>host, :port=>port, :thread_safe=>true, :db=>db, :thread_safe=>true)
      when Redis
        @connection_spec = nil
        @redis = spec_or_connection
      when :mock
        @connection_spec = nil
        @redis = MockRedis.new
      else
        raise "I don't know what to do with #{spec_or_connection.inspect}"
      end
    end

    def redis
      self.redis = @connection_spec unless @redis
      @redis
    end

    def connected?
      !@redis.nil?
    end

    def disconnect!
      @redis.quit if connected? rescue nil
      @redis = nil
    end

    def reconnect!
      raise "Connect reconnect without connection specification" unless String === @connection_spec
      disconnect! rescue nil
    end

    def mock!
      warn "Deprecated: use Vanity.playground.test!"
      test!
    end
   
    # Use this when testing to disable Redis (e.g. if your CI server doesn't
    # have Redis). 
    #
    # @example Put this in config/environments/test.rb
    #   config.after_initialize { Vanity.playground.test! }
    def test!
      self.redis = :mock
    end
  end

  @playground = Playground.new
  class << self

    # The playground instance.
    #
    # @see Vanity::Playground
    attr_accessor :playground

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
  # @deprecated
  def experiment(name)
    warn "Deprecated. Please call Vanity.playground.experiment directly."
    Vanity.playground.experiment(name)
  end
end
