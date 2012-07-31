module Vanity
  module Adapters

    class << self
      # Creates new connection to underlying datastore and returns suitable
      # adapter (adapter object extends AbstractAdapter and wraps the
      # connection). Vanity.playgroup.establish_connection uses this.
      #
      # @since 1.4.0
      def establish_connection(spec)
        begin
          require "vanity/adapters/#{spec[:adapter]}_adapter"
        rescue LoadError
          raise "Could not find #{spec[:adapter]} in your load path"
        end
        adapter_method = "#{spec[:adapter]}_connection"
        send adapter_method, spec
      end
    end

    # Base class for all adapters. Adapters wrap underlying connection to a
    # datastore and implement an API that Vanity can use to store/access
    # metrics, experiments, etc.
    class AbstractAdapter
      # Returns true if connected.
      def active?
        false
      end

      # Close connection, release any resources.
      def disconnect!
      end

      # Close and reopen connection.
      def reconnect!
      end

      # Empty the database. This is used during tests.
      def flushdb
      end
      

      # -- Metrics --
     
      # Return when metric was last updated.
      def get_metric_last_update_at(metric)
        fail "Not implemented"
      end
  
      # Track metric data.
      def metric_track(metric, timestamp, identity, values)
        fail "Not implemented"
      end

      # Returns all the metric values between from and to time instances
      # (inclusive). Returns pairs of date and total count for that date.
      def metric_values(metric, from, to)
        fail "Not implemented"
      end

      # Deletes all information about this metric.
      def destroy_metric(metric)
        fail "Not implemented"
      end


      # -- Experiments --

      # Store whether an experiment is enabled or not
      def set_experiment_enabled(experiment, enabled)
        fail "Not implemented"
      end
      
      # Returns true if experiment is enabled, the default (if enabled has not yet been set) is false*
      # (*except for mock_adapter, where default is true for testing)
      def is_experiment_enabled?(experiment)
        fail "Not implemented"
      end

      # Store when experiment was created (do not write over existing value). 
      def set_experiment_created_at(experiment, time)
        fail "Not implemented"
      end

      # Return when experiment was created.
      def get_experiment_created_at(experiment)
        fail "Not implemented"
      end
     
      # Returns true if experiment completed. 
      def is_experiment_completed?(experiment)
        fail "Not implemented"
      end

      # Returns counts for given A/B experiment and alternative (by index).
      # Returns hash with values for the keys :participants, :converted and
      # :conversions.
      def ab_counts(experiment, alternative)
        fail "Not implemented"
      end
      
      # Returns metric counts for given A/B experiment and alternative (by index).
      # Returns hash with metric names as keys and metric counts as values
      def ab_metric_counts(experiment, alternative)
        fail "Not implemented"
      end

      # Pick particular alternative (by index) to show to this particular
      # participant (by identity).
      def ab_show(experiment, identity, alternative)
        fail "Not implemented"
      end

      # Indicates which alternative to show to this participant. See #ab_show.
      def ab_showing(experiment, identity)
        fail "Not implemented"
      end

      # Cancels previously set association between identity and alternative. See
      # #ab_show.
      def ab_not_showing(experiment, identity)
        fail "Not implemented"
      end

      # Records a participant in this experiment for the given alternative.
      def ab_add_participant(experiment, alternative, identity)
        fail "Not implemented"
      end

      # Records a conversion in this experiment for the given alternative.
      # Associates a value with the conversion (default to 1). If implicit is
      # true, add particpant if not already recorded for this experiment. If
      # implicit is false (default), only add conversion is participant
      # previously recorded as participating in this experiment.
      def ab_add_conversion(experiment, alternative, identity, count = 1, implicit = false)
        fail "Not implemented"
      end
      
      # Records a tracked metric in this experiment for the given alternative.
      def ab_add_metric_count(experiment, alternative, metric, count = 1)
        fail "Not implemented"
      end

      # Returns the outcome of this expriment (if set), the index of a
      # particular alternative.
      def ab_get_outcome(experiment)
        fail "Not implemented"
      end

      # Sets the outcome of this experiment to a particular alternative.
      def ab_set_outcome(experiment, alternative = 0)
        fail "Not implemented"
      end

      # Deletes all information about this experiment.
      def destroy_experiment(experiment)
        fail "Not implemented"
      end
    end
  end
end
