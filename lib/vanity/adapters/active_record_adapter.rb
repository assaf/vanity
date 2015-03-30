module Vanity
  module Adapters
    class << self
      # Creates new ActiveRecord connection and returns ActiveRecordAdapter.
      def active_record_connection(spec)
        require "active_record"
        ActiveRecordAdapter.new(spec)
      end
    end

    # ActiveRecord adapter
    class ActiveRecordAdapter < AbstractAdapter
      # Base model, stores connection and defines schema
      class VanityRecord < ActiveRecord::Base
        self.abstract_class = true

        def self.needs_attr_accessible?
          respond_to?(:attr_accessible) && (!defined?(ActionController::StrongParameters) || defined?(ProtectedAttributes))
        end

        def self.rails_agnostic_find_or_create_by(method, value)
          if respond_to? :find_or_create_by
            find_or_create_by(method => value)
          else
            send :"find_or_create_by_#{method}", value
          end
        end
      end

      # Metric model
      class VanityMetric < VanityRecord
        UPDATED_AT_GRACE_PERIOD = 1.minute
        self.table_name = :vanity_metrics
        has_many :vanity_metric_values
        attr_accessible :metric_id if needs_attr_accessible?

        def self.retrieve(metric)
          rails_agnostic_find_or_create_by(:metric_id, metric.to_s)
        end

        def touch_with_grace_period
          now = Time.now
          self.updated_at = now if updated_before_grace_period?(now)
        end

        private

        def updated_before_grace_period?(now)
          now - updated_at >= UPDATED_AT_GRACE_PERIOD
        end
      end

      # Metric value
      class VanityMetricValue < VanityRecord
        attr_accessible :date, :index, :value if needs_attr_accessible?

        self.table_name = :vanity_metric_values
        belongs_to :vanity_metric
      end

      # Experiment model
      class VanityExperiment < VanityRecord
        self.table_name = :vanity_experiments
        has_many :vanity_conversions, :dependent => :destroy
        attr_accessible :experiment_id if needs_attr_accessible?

        # Finds or creates the experiment
        def self.retrieve(experiment)
          rails_agnostic_find_or_create_by(:experiment_id, experiment.to_s)
        end

        def increment_conversion(alternative, count = 1)
          record = vanity_conversions.rails_agnostic_find_or_create_by(:alternative, alternative)
          record.increment!(:conversions, count)
        end
      end

      # Conversion model
      class VanityConversion < VanityRecord
        self.table_name = :vanity_conversions
        belongs_to :vanity_experiment
      end

      # Participant model
      class VanityParticipant < VanityRecord
        self.table_name = :vanity_participants
        attr_accessible :experiment_id, :identity, :seen, :shown, :converted if needs_attr_accessible?

        # Finds the participant by experiment and identity. If create is true
        # then it will create the participant if not found. If a hash is
        # passed then this will be passed to create if creating, or will be
        # used to update the found participant.
        def self.retrieve(experiment, identity, create = true, update_with = nil)
          if record = VanityParticipant.where(:experiment_id=>experiment.to_s, :identity=>identity.to_s).first
            record.update_attributes(update_with) if update_with
          elsif create
            record = VanityParticipant.create({ :experiment_id=>experiment.to_s, :identity=>identity.to_s }.merge(update_with || {}))
          end
          record
        end
      end

      def initialize(options)
        @options = options.inject({}) { |h,kv| h[kv.first.to_s] = kv.last ; h }
        if @options["active_record_adapter"] && (@options["active_record_adapter"] != "default")
          @options["adapter"] = @options["active_record_adapter"]
          VanityRecord.establish_connection(@options)
        end
      end

      def active?
        VanityRecord.connected? && VanityRecord.connection.active?
      end

      def disconnect!
        VanityRecord.connection.disconnect! if active?
      end

      def reconnect!
        VanityRecord.connection.reconnect!
      end

      def flushdb
        [VanityExperiment, VanityMetric, VanityParticipant, VanityMetricValue, VanityConversion].each do |klass|
          klass.delete_all
        end
      end


      # -- Metrics --

      def get_metric_last_update_at(metric)
        record = VanityMetric.find_by_metric_id(metric.to_s)
        record && record.updated_at
      end

      def metric_track(metric, timestamp, identity, values)
        record = VanityMetric.retrieve(metric)

        values.each_with_index do |value, index|
          record.vanity_metric_values.create(:date => timestamp.to_date.to_s, :index => index, :value => value)
        end

        record.touch_with_grace_period
        record.save
      end

      def metric_values(metric, from, to)
        connection = VanityMetric.connection
        record = VanityMetric.retrieve(metric)
        dates = (from.to_date..to.to_date).map(&:to_s)
        conditions = [connection.quote_column_name('date') + ' BETWEEN ? AND ?', from.to_date, to.to_date]
        order = "#{connection.quote_column_name('date')}"
        select = "sum(#{connection.quote_column_name('value')}) AS value, #{connection.quote_column_name('date')}"
        group_by = "#{connection.quote_column_name('date')}"

        values = record.vanity_metric_values.select(select).where(conditions).group(group_by)

        dates.map do |date|
          value = values.detect{|v| v.date == date }
          [(value && value.value) || 0]
        end
      end

      def destroy_metric(metric)
        record = VanityMetric.find_by_metric_id(metric.to_s)
        record && record.destroy
      end


      # -- Experiments --

      def experiment_persisted?(experiment)
        VanityExperiment.find_by_experiment_id(experiment.to_s).present?
      end

      # Store when experiment was created (do not write over existing value).
      def set_experiment_created_at(experiment, time)
        record = VanityExperiment.find_by_experiment_id(experiment.to_s) ||
                VanityExperiment.new(:experiment_id => experiment.to_s)
        record.created_at ||= time
        record.save
      end

      # Return when experiment was created.
      def get_experiment_created_at(experiment)
        record = VanityExperiment.retrieve(experiment)
        record && record.created_at
      end

      def set_experiment_completed_at(experiment, time)
        VanityExperiment.retrieve(experiment).update_attribute(:completed_at, time)
      end

      def get_experiment_completed_at(experiment)
        VanityExperiment.retrieve(experiment).completed_at
      end

      # Returns true if experiment completed.
      def is_experiment_completed?(experiment)
        !!VanityExperiment.retrieve(experiment).completed_at
      end

      # Returns counts for given A/B experiment and alternative (by index).
      # Returns hash with values for the keys :participants, :converted and
      # :conversions.
      def ab_counts(experiment, alternative)
        record = VanityExperiment.retrieve(experiment)
        participants = VanityParticipant.where(:experiment_id => experiment.to_s, :seen => alternative).count
        converted = VanityParticipant.where(:experiment_id => experiment.to_s, :converted => alternative).count
        conversions = record.vanity_conversions.where(:alternative => alternative).sum(:conversions)

        {
          :participants => participants,
          :converted => converted,
          :conversions => conversions
        }
      end

      # Pick particular alternative (by index) to show to this particular
      # participant (by identity).
      def ab_show(experiment, identity, alternative)
        VanityParticipant.retrieve(experiment, identity, true, :shown => alternative)
      end

      # Indicates which alternative to show to this participant. See #ab_show.
      def ab_showing(experiment, identity)
        participant = VanityParticipant.retrieve(experiment, identity, false)
        participant && participant.shown
      end

      # Cancels previously set association between identity and alternative. See
      # #ab_show.
      def ab_not_showing(experiment, identity)
        VanityParticipant.retrieve(experiment, identity, true, :shown => nil)
      end

      # Records a participant in this experiment for the given alternative.
      def ab_add_participant(experiment, alternative, identity)
        VanityParticipant.retrieve(experiment, identity, true, :seen => alternative)
      end

      # Determines if a participant already has seen this alternative in this experiment.
      def ab_seen(experiment, identity, alternative)
        participant = VanityParticipant.retrieve(experiment, identity, false)
        participant && participant.seen == alternative.id
      end

      # Returns the participant's seen alternative in this experiment, if it exists
      def ab_assigned(experiment, identity)
        participant = VanityParticipant.retrieve(experiment, identity, false)
        participant && participant.seen
      end

      # Records a conversion in this experiment for the given alternative.
      # Associates a value with the conversion (default to 1). If implicit is
      # true, add participant if not already recorded for this experiment. If
      # implicit is false (default), only add conversion if participant
      # previously recorded as participating in this experiment.
      def ab_add_conversion(experiment, alternative, identity, count = 1, implicit = false)
        participant = VanityParticipant.retrieve(experiment, identity, false)
        VanityParticipant.retrieve(experiment, identity, implicit, :converted => alternative)
        VanityExperiment.retrieve(experiment).increment_conversion(alternative, count)
      end

      # Returns the outcome of this experiment (if set), the index of a
      # particular alternative.
      def ab_get_outcome(experiment)
        VanityExperiment.retrieve(experiment).outcome
      end

      # Sets the outcome of this experiment to a particular alternative.
      def ab_set_outcome(experiment, alternative = 0)
        VanityExperiment.retrieve(experiment).update_attribute(:outcome, alternative)
      end

      # Deletes all information about this experiment.
      def destroy_experiment(experiment)
        VanityParticipant.delete_all(:experiment_id => experiment.to_s)
        record = VanityExperiment.find_by_experiment_id(experiment.to_s)
        record && record.destroy
      end

      def to_s
        @options.to_s
      end
    end
  end
end
