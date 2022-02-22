module Vanity
  module Adapters
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
      def get_metric_last_update_at(_metric)
        raise "Not implemented"
      end

      # Track metric data.
      def metric_track(_metric, _timestamp, _identity, _values)
        raise "Not implemented"
      end

      # Returns all the metric values between from and to time instances
      # (inclusive). Returns pairs of date and total count for that date.
      def metric_values(_metric, _from, _to)
        raise "Not implemented"
      end

      # Deletes all information about this metric.
      def destroy_metric(_metric)
        raise "Not implemented"
      end

      # -- Experiments --

      def experiment_persisted?(_experiment)
        raise "Not implemented"
      end

      # Store when experiment was created (do not write over existing value).
      def set_experiment_created_at(_experiment, _time)
        raise "Not implemented"
      end

      # Return when experiment was created.
      def get_experiment_created_at(_experiment)
        raise "Not implemented"
      end

      # Returns true if experiment completed.
      def is_experiment_completed?(_experiment) # rubocop:todo Naming/PredicateName
        raise "Not implemented"
      end

      # Store whether an experiment is enabled or not
      def set_experiment_enabled(_experiment, _enabled)
        raise "Not implemented"
      end

      # Returns true if experiment is enabled, the default (Vanity.configuration.experiments_start_enabled) is true.
      # (*except for mock_adapter, where default is true for testing)
      def is_experiment_enabled?(_experiment) # rubocop:todo Naming/PredicateName
        raise "Not implemented"
      end

      # Returns counts for given A/B experiment and alternative (by index).
      # Returns hash with values for the keys :participants, :converted and
      # :conversions.
      def ab_counts(_experiment, _alternative)
        raise "Not implemented"
      end

      # Pick particular alternative (by index) to show to this particular
      # participant (by identity).
      def ab_show(_experiment, _identity, _alternative)
        raise "Not implemented"
      end

      # Indicates which alternative to show to this participant. See #ab_show.
      def ab_showing(_experiment, _identity)
        raise "Not implemented"
      end

      # Cancels previously set association between identity and alternative. See
      # #ab_show.
      def ab_not_showing(_experiment, _identity)
        raise "Not implemented"
      end

      # Records a participant in this experiment for the given alternative.
      def ab_add_participant(_experiment, _alternative, _identity)
        raise "Not implemented"
      end

      # Determines if a participant already has seen this alternative in this experiment.
      def ab_seen(_experiment, _identity, _assignment)
        raise "Not implemented"
      end

      # Determines what alternative a participant has already been given, if any
      def ab_assigned(_experiment, _identity)
        raise "Not implemented"
      end

      # Records a conversion in this experiment for the given alternative.
      # Associates a value with the conversion (default to 1). If implicit is
      # true, add particpant if not already recorded for this experiment. If
      # implicit is false (default), only add conversion is participant
      # previously recorded as participating in this experiment.
      def ab_add_conversion(_experiment, _alternative, _identity, _count = 1, _implicit = false)
        raise "Not implemented"
      end

      # Returns the outcome of this expriment (if set), the index of a
      # particular alternative.
      def ab_get_outcome(_experiment)
        raise "Not implemented"
      end

      # Sets the outcome of this experiment to a particular alternative.
      def ab_set_outcome(_experiment, _alternative = 0)
        raise "Not implemented"
      end

      # Deletes all information about this experiment.
      def destroy_experiment(_experiment)
        raise "Not implemented"
      end

      private

      def with_ab_seen_deprecation(experiment, identity, alternative)
        if alternative.respond_to?(:id)
          Vanity.configuration.logger.warn('Deprecated: #ab_seen should be passed the alternative id, not an Alternative instance')
          yield experiment, identity, alternative.id
        else
          yield experiment, identity, alternative
        end
      end
    end
  end
end
