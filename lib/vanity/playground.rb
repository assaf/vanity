module Vanity

  # These methods are available from experiment definitions (files located in
  # the experiments directory, automatically loaded by Vanity).  Use these
  # methods to define you experiments, for example:
  #   ab_test "New Banner" do
  #     alternatives :red, :green, :blue
  #   end
  module Definition

  protected
    # Defines a new experiment, given the experiment's name, type and
    # definition block.
    def define(name, type, options = nil, &block)
      options ||= {}
      Vanity.playground.define(name, type, options, &block)
    end

  end

  # Playground catalogs all your experiments, holds the Vanity configuration.
  # For example:
  #   Vanity.playground.logger = my_logger
  #   puts Vanity.playground.map(&:name)
  class Playground

    DEFAULTS = { :host=>"127.0.0.1", :port=>6379, :db=>0 }

    # Created new Playground. Unless you need to, use the global Vanity.playground.
    def initialize
      @experiments = {}
      @metrics = {}
      @host, @port, @db = DEFAULTS.values_at(:host, :port, :db)
      @namespace = "vanity:#{Vanity::Version::MAJOR}"
      @load_path = "experiments"
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::ERROR
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
      id = name.to_s.downcase.gsub(/\W/, "_")
      raise "Experiment #{id} already defined once" if @experiments[id]
      klass = Experiment.const_get(type.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase })
      experiment = klass.new(self, id, name, options)
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
        @loading ||= []
        fail "Circular dependency detected: #{@loading.join('=>')}=>#{id}" if @loading.include?(id)
        begin
          @loading.push id
          source = File.read(File.expand_path("#{id}.rb", load_path))
          context = Object.new
          context.instance_eval do
            extend Definition
            eval source
          end
        rescue
          error = LoadError.exception($!.message)
          error.set_backtrace $!.backtrace
          raise error
        ensure
          @loading.pop
        end
      end
      @experiments[id] or fail LoadError, "Expected experiments/#{id}.rb to define experiment #{name}"
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
    end

    # Use this instance to access the Redis database.
    def redis
      redis = Redis.new(host: self.host, port: self.port, db: self.db,
                        password: self.password, logger: self.logger)
      class << self ; self ; end.send(:define_method, :redis) { redis }
      redis
    end

    # Returns a metric (creating one if doesn't already exist).
    def metric(id)
      id = id.to_sym
      @metrics[id] ||= Metric.new(self, id)
    end

    # Returns hash of metrics (key is metric id).
    def metrics
      @metrics
    end

    # Tracks an action associated with a metric.  For example:
    #   Vanity.playground.track! :uploaded_video
    def track!(id)
      metric(id).track! Vanity.context.vanity_identity
    end
  end

  @playground = Playground.new
  class << self

    # Returns the playground instance.
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

  # Use this method to access an experiment by name.  For example:
  #   puts experiment(:text_size).alternatives
  def experiment(name)
    Vanity.playground.experiment(name)
  end
end
