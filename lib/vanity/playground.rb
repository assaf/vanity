require "uri"

module Vanity
  # Playground catalogs all your experiments. For configuration please see
  # Vanity::Configuration, for connection management, please see
  # Vanity::Connection.
  class Playground

    # Created new Playground. Unless you need to, use the global
    # Vanity.playground.
    def initialize
      @loading = []
    end

    # @deprecated
    # @see Configuration#experiments_path
    def load_path
      Vanity.configuration.experiments_path
    end

    # @deprecated
    # @see Configuration#experiments_path
    def load_path=(path)
      Vanity.configuration.experiments_path = path
    end

    # @deprecated
    # @see Configuration#logger
    def logger
      Vanity.configuration.logger
    end

    # @deprecated
    # @see Configuration#logger
    def logger=(logger)
      Vanity.configuration.logger = logger
    end

    # @deprecated
    # @see Configuration#templates_path
    def custom_templates_path
      Vanity.configuration.templates_path
    end

    def custom_templates_path=(path)
      Vanity.configuration.templates_path = path
    end

    # @deprecated
    # @see Configuration#use_js
    def use_js!
      Vanity.configuration.use_js = true
    end

    # @deprecated
    # @see Configuration#use_js
    def using_js?
      Vanity.configuration.use_js
    end

    # @deprecated
    # @see Configuration#add_participant_route
    def add_participant_path
      Vanity.configuration.add_participant_route
    end

    # @deprecated
    # @see Configuration#add_participant_route=
    def add_participant_path=(path)
      Vanity.configuration.add_participant_route=path
    end

    # @since 1.9.0
    # @deprecated
    # @see Configuration#failover_on_datastore_error
    def failover_on_datastore_error!
      Vanity.configuration.failover_on_datastore_error = true
    end

    # @since 1.9.0
    # @deprecated
    # @see Configuration#failover_on_datastore_error
    def failover_on_datastore_error?
      Vanity.configuration.failover_on_datastore_error
    end

    # @since 1.9.0
    # @deprecated
    # @see Configuration#on_datastore_error
    def on_datastore_error
      Vanity.configuration.on_datastore_error
    end

    # @deprecated
    # @see Configuration#on_datastore_error
    def on_datastore_error=(closure)
      Vanity.configuration.on_datastore_error = closure
    end

    # @since 1.9.0
    # @deprecated
    # @see Configuration#request_filter
    def request_filter
      Vanity.configuration.request_filter
    end

    # @deprecated
    # @see Configuration#request_filter=
    def request_filter=(filter)
      Vanity.configuration.request_filter = filter
    end

    # @since 1.4.0
    # @deprecated
    # @see Configuration#collecting
    def collecting?
      Vanity.configuration.collecting
    end

    # @since 1.4.0
    # @deprecated
    # @see Configuration#collecting
    def collecting=(enabled)
      Vanity.configuration.collecting = enabled
    end

    # @deprecated
    # @see Vanity#reload!
    def reload!
      Vanity.reload!
    end

    # @deprecated
    # @see Vanity#load!
    def load!
      Vanity.load!
    end

    # Returns hash of experiments (key is experiment id). This creates the
    # Experiment and persists it to the datastore.
    #
    # @see Vanity::Experiment
    def experiments
      return @experiments if @experiments

      @experiments = {}
      Vanity.logger.info("Vanity: loading experiments from #{Vanity.configuration.experiments_path}")
      Dir[File.join(Vanity.configuration.experiments_path, "*.rb")].each do |file|
        Experiment::Base.load(self, @loading, file)
      end
      @experiments
    end

    def experiments_persisted?
      experiments.keys.all? { |id| connection.experiment_persisted?(id) }
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
    # @deprecated
    def metrics
      unless @metrics
        @metrics = {}
        Vanity.logger.info("Vanity: loading metrics from #{Vanity.configuration.experiments_path}/metrics")

        Dir[File.join(Vanity.configuration.experiments_path, "metrics/*.rb")].each do |file|
          Metric.load(self, @loading, file)
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
      metric(id).track!(count)
    end

    # Returns the experiment. You may not have guessed, but this method raises
    # an exception if it cannot load the experiment's definition.
    #
    # @see Vanity::Experiment
    # @deprecated
    def experiment(name)
      id = name.to_s.downcase.gsub(/\W/, "_").to_sym
      Vanity.logger.warn("Deprecated: Please call experiment method with experiment identifier (a Ruby symbol)") unless id == name
      experiments[id.to_sym] or raise NoExperimentError, "No experiment #{id}"
    end


    # -- Participant Information --

    # Returns an array of all experiments this participant is involved in, with their assignment.
    #  This is done as an array of arrays [[<experiment_1>, <assignment_1>], [<experiment_2>, <assignment_2>]], sorted by experiment name, so that it will give a consistent string
    #  when converted to_s (so could be used for caching, for example)
    def participant_info(participant_id)
      participant_array = []
      experiments.values.sort_by(&:name).each do |e|
        index = connection.ab_assigned(e.id, participant_id)
        if index
          participant_array << [e, e.alternatives[index.to_i]]
        end
      end
      participant_array
    end

    # @since 1.4.0
    # @deprecated
    # @see Vanity::Connection
    def establish_connection(spec=nil)
      disconnect!
      Vanity.connect!(spec)
    end

    # @since 1.4.0
    # @deprecated
    # @see Vanity.connection
    def connection
      Vanity.connection.adapter
    end

    # @since 1.4.0
    # @deprecated
    # @see Vanity.connection
    def connected?
      Vanity.connection.connected?
    end

    # @since 1.4.0
    # @deprecated
    # @see Vanity.disconnect!
    def disconnect!
      Vanity.disconnect!
    end

    # Closes the current connection and establishes a new one.
    #
    # @since 1.3.0
    # @deprecated
    def reconnect!
      Vanity.reconnect!
    end
  end
end
