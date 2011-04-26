require "uri"

module Vanity

  # Playground catalogs all your experiments, holds the Vanity configuration.
  #
  # @example
  #   Vanity.playground.logger = my_logger
  #   puts Vanity.playground.map(&:name)
  class Playground

    DEFAULTS = { :collecting => true, :load_path=>"experiments" }
    DEFAULT_ADD_PARTICIPANT_PATH = '/vanity/add_participant'

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
      options = Hash === args.last ? args.pop : {}
      # In the case of Rails, use the Rails logger and collect only for
      # production environment by default.
      defaults = options[:rails] ? DEFAULTS.merge(:collecting => ::Rails.env.production?, :logger => ::Rails.logger) : DEFAULTS
      if File.exists?("config/vanity.yml")
        env = ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
        config = YAML.load(ERB.new(File.read("config/vanity.yml")).result)[env]
        if Hash === config
          config = config.inject({}) { |h,kv| h[kv.first.to_sym] = kv.last ; h }
        else
          config = { :connection=>config }
        end
      else
        config = {}
      end

      @options = defaults.merge(config).merge(options)
      if @options.values_at(:host, :port, :db).any?
        warn "Deprecated: please specify Redis connection as URL (\"redis://host:port/db\")"
        establish_connection :adapter=>"redis", :host=>@options[:host], :port=>@options[:port], :database=>@options[:db] || @options[:database]
      elsif @options[:redis]
        @adapter = RedisAdapter.new(:redis=>@options[:redis])
      else
        connection_spec = args.shift || @options[:connection]
        if connection_spec
          connection_spec = "redis://" + connection_spec unless connection_spec[/^\w+:/]
          establish_connection connection_spec
        end
      end

      warn "Deprecated: namespace option no longer supported directly" if @options[:namespace]
      @load_path = @options[:load_path] || DEFAULTS[:load_path]
      unless @logger = @options[:logger]
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::ERROR
      end
      @loading = []
      @bot_resistant = false
      self.add_participant_path = DEFAULT_ADD_PARTICIPANT_PATH
      @collecting = !!@options[:collecting]
    end
   
    # Deprecated. Use redis.server instead.
    attr_accessor :host, :port, :db, :password, :namespace

    # Path to load experiment files from.
    attr_accessor :load_path

    # Logger.
    attr_accessor :logger

    attr_accessor :add_participant_path

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


    # -- Robot Detection --

    # Call to indicate that participants should be added via js
    # This helps keep robots from participating in the ab test
    # and skewing results.
    #
    # Be sure to add <%= Vanity.participant_js %> to pages that 
    # have ab tests if you are using the bot_resistant code.
    def be_bot_resistant
      @bot_resistant = true
    end

    def bot_resistant?
      @bot_resistant
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

    # True if collection data (metrics and experiments). You only want to
    # collect data in production environment, everywhere else run with
    # collection off.
    #
    # @since 1.4.0
    def collecting?
      @collecting
    end

    # Turns data collection on and off.
    #
    # @since 1.4.0
    def collecting=(enabled)
      @collecting = !!enabled
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
        if File.exist?("config/vanity.yml") && remote = YAML.load(ERB.new(File.read("config/vanity.yml")).result)["metrics"]
          remote.each do |id, url|
            fail "Metric #{id} already defined in playground" if metrics[id.to_sym]
            metric = Metric.new(self, id)
            metric.remote url
            metrics[id.to_sym] = metric
          end
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
 
    # This is the preferred way to programmatically create a new connection (or
    # switch to a new connection). If no connection was established, the
    # playground will create a new one by calling this method with no arguments.
    #
    # With no argument, uses the connection specified in config/vanity.yml file
    # for the current environment (RACK_ENV, RAILS_ENV or development). If there
    # is no config/vanity.yml file, picks the configuration from
    # config/redis.yml, or defaults to Redis on localhost, port 6379.
    #
    # If the argument is a symbol, uses the connection specified in
    # config/vanity.yml for that environment. For example:
    #   Vanity.playground.establish_connection :production
    #
    # If the argument is a string, it is processed as a URL. For example:
    #   Vanity.playground.establish_connection "redis://redis.local/5"
    #
    # Otherwise, the argument is a hash and specifies the adapter name and any
    # additional options understood by that adapter (as with config/vanity.yml).
    # For example:
    #   Vanity.playground.establish_connection :adapter=>:redis,
    #                                          :host=>"redis.local"
    #
    # @since 1.4.0 
    def establish_connection(spec = nil)
      disconnect! if @adapter
      case spec
      when nil
        if File.exists?("config/vanity.yml")
          env = ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
          spec = YAML.load(ERB.new(File.read("config/vanity.yml")).result)[env]
          fail "No configuration for #{env}" unless spec
          establish_connection spec
        elsif File.exists?("config/redis.yml")
          env = ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
          redis = YAML.load(ERB.new(File.read("config/redis.yml")).result)[env]
          fail "No configuration for #{env}" unless redis
          establish_connection "redis://" + redis
        else
          establish_connection :adapter=>"redis"
        end
      when Symbol
        spec = YAML.load(ERB.new(File.read("config/vanity.yml")).result)[spec.to_s]
        establish_connection spec
      when String
        uri = URI.parse(spec)
        params = CGI.parse(uri.query) if uri.query
        establish_connection :adapter=>uri.scheme, :username=>uri.user, :password=>uri.password,
          :host=>uri.host, :port=>uri.port, :path=>uri.path, :params=>params
      else
        spec = spec.inject({}) { |hash,(k,v)| hash[k.to_sym] = v ; hash }
        begin
          require "vanity/adapters/#{spec[:adapter]}_adapter"
        rescue LoadError
          raise "Could not find #{spec[:adapter]} in your load path"
        end
        @adapter = Adapters.establish_connection(spec)
      end
    end

    # Returns the current connection. Establishes new connection is necessary.
    #
    # @since 1.4.0
    def connection
      @adapter || establish_connection
    end

    # Returns true if connection is open.
    #
    # @since 1.4.0
    def connected?
      @adapter && @adapter.active?
    end

    # Closes the current connection.
    #
    # @since 1.4.0
    def disconnect!
      @adapter.disconnect! if @adapter
    end

    # Closes the current connection and establishes a new one.
    #
    # @since 1.3.0
    def reconnect!
      establish_connection
    end

    # Deprecated. Use Vanity.playground.collecting = true/false instead.  Under
    # Rails, collecting is true in production environment, false in all other
    # environments, which is exactly what you want.
    def test!
      warn "Deprecated: use collecting = false instead"
      self.collecting = false
    end

    # Deprecated. Use establish_connection or configuration file instead.
    def redis=(spec_or_connection)
      warn "Deprecated: use establish_connection method instead"
      case spec_or_connection
      when String
        establish_connection "redis://" + spec_or_connection
      when ::Redis
        @connection = Adapters::RedisAdapter.new(spec_or_connection)
      when :mock
        establish_connection :adapter=>:mock
      else
        raise "I don't know what to do with #{spec_or_connection.inspect}"
      end
    end

    def redis
      warn "Deprecated: use connection method instead"
      connection
    end

  end

  # In the case of Rails, use the Rails logger and collect only for
  # production environment by default.
  @playground = Playground.new(:rails=>defined?(::Rails))
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
