require 'test_helper'
require 'time'

describe Vanity::Adapters::MockAdapter do

  def identity
    'test-identity'
  end

  def experiment
    :experiment
  end

  def alternative
    1
  end

  def metric
    :purchases
  end

  def run_experiment
    @subject.ab_add_participant(experiment, alternative, identity)
    @subject.ab_add_participant(experiment, alternative, 'other-identity')
    @subject.ab_add_conversion(experiment, alternative, identity, 2)
  end

  before do
    @subject = Vanity::Adapters::MockAdapter.new({})
    @subject.flushdb
  end

  describe 'metrics methods' do
    describe '#get_metric_last_update_at' do
      it 'is nil if the metric has never been tracked' do
        refute(@subject.get_metric_last_update_at(metric))
      end

      it 'returns the time of the last tracked event if present' do
        time = Time.now
        @subject.metric_track(metric, time, identity, [1])

        assert_in_delta(
          time,
          @subject.get_metric_last_update_at(metric),
          0.1
        )
      end
    end

    describe '#metric_values' do
      it 'returns the tracked metrics from the given range, binned by date' do
        time_1 = Time.iso8601("2016-01-01T00:00:00+00:00")
        time_2 = Time.iso8601("2016-01-01T12:00:00+00:00")
        time_3 = Time.iso8601("2016-01-02T00:00:00+00:00")
        time_4 = Time.iso8601("2016-01-02T12:00:00+00:00")
        time_5 = Time.iso8601("2016-01-03T12:00:00+00:00")

        @subject.metric_track(metric, time_1, identity, [1, 1])
        @subject.metric_track(metric, time_2, identity, [2, 1])
        @subject.metric_track(metric, time_3, identity, [3])
        @subject.metric_track(metric, time_4, identity, [4, 10])
        @subject.metric_track(metric, time_5, identity, [5])

        assert_equal(
          [[3, 2], [7, 10]],
          @subject.metric_values(metric, time_1, time_4)
        )
      end
    end

    describe '#destroy_metric' do
      it 'removes all data related to the metric' do
        @subject.metric_track(metric, Time.now, identity, [1])

        @subject.destroy_metric(metric)

        refute(@subject.get_metric_last_update_at(metric))
      end
    end
  end

  describe 'generic experiment methods' do
    describe '#experiment_persisted?' do
      it 'returns false if the experiment is unknown' do
        refute(@subject.experiment_persisted?(experiment))
      end

      it 'returns true if the experiment has data' do
        run_experiment

        assert(@subject.experiment_persisted?(experiment))
      end
    end

    describe '#set_experiment_created_at' do
      it 'sets the experiment creation date' do
        time = Time.now
        @subject.set_experiment_created_at(experiment, time)

        assert_equal(time, @subject.get_experiment_created_at(experiment))
      end
    end

    describe '#destroy_experiment' do
      it 'removes all information about the experiment' do
        run_experiment
        @subject.destroy_experiment(experiment)

        refute(@subject.experiment_persisted?(experiment))
      end
    end

    describe '#is_experiment_enabled?' do
      def with_experiments_start_enabled(enabled)
        begin
          original_value = Vanity.configuration.experiments_start_enabled
          Vanity.configuration.experiments_start_enabled = enabled
          yield
        ensure
          Vanity.configuration.experiments_start_enabled = original_value
        end
      end

      describe 'when experiments start enabled' do
        it 'is true when the enabled value is unset' do
          with_experiments_start_enabled(true) do
            assert(@subject.is_experiment_enabled?(experiment))
          end
        end

        it 'is false when the enabled value is set to false' do
          with_experiments_start_enabled(true) do
            @subject.set_experiment_enabled(experiment, false)

            refute(@subject.is_experiment_enabled?(experiment))
          end
        end
      end

      describe 'when experiments do not start enabled' do
        it 'is false when the enabled value is unset' do
          with_experiments_start_enabled(false) do
            refute(@subject.is_experiment_enabled?(experiment))
          end
        end

        it 'is true when the enabled value is set to true' do
          with_experiments_start_enabled(false) do
            @subject.set_experiment_enabled(experiment, true)

            assert(@subject.is_experiment_enabled?(experiment))
          end
        end
      end
    end

    describe '#is_experiment_completed?' do
      it 'is true if the completion date is set' do
        @subject.set_experiment_completed_at(experiment, Time.now)

        assert(@subject.is_experiment_completed?(experiment))
      end

      it 'is false if the completion date is unset' do
        refute(@subject.is_experiment_completed?(experiment))
      end
    end
  end

  describe 'A/B test methods' do
    describe '#ab_add_conversion' do
      it 'adds the participant and the conversion when implicit=true' do
        @subject.ab_add_conversion(experiment, alternative, identity, 1, true)

        assert_equal(
          {:participants => 1, :conversions => 1, :converted => 1},
          @subject.ab_counts(experiment, alternative)
        )
      end
    end

    describe '#ab_add_participant' do
      it 'adds the participant to the specified alternative' do
        @subject.ab_add_participant(experiment, alternative, identity)

        assert_equal(
          {:participants => 1, :conversions => 0, :converted => 0},
          @subject.ab_counts(experiment, alternative)
        )
      end
    end

    describe '#ab_counts' do
      it 'returns the counts of participants, conversions and converted for the alternative' do
        run_experiment

        assert_equal(
          {:participants => 2, :conversions => 2, :converted => 1},
          @subject.ab_counts(experiment, alternative)
        )
      end
    end

    describe '#ab_get_outcome' do
      it 'returns the outcome if one is set' do
        @subject.ab_set_outcome(experiment, alternative)

        assert_equal(
          alternative,
          @subject.ab_get_outcome(experiment)
        )
      end

      it 'returns nil otherwise' do
        assert_equal(
          nil,
          @subject.ab_get_outcome(experiment)
        )
      end
    end

    describe '#ab_show' do
      it 'forces an alternative to be shown to the given identity' do
        @subject.ab_show(experiment, identity, alternative)

        assert_equal(
          alternative,
          @subject.ab_showing(experiment, identity)
        )
      end
    end

    describe '#ab_not_showing' do
      it 'cancels a previously-set showing alternative' do
        @subject.ab_show(experiment, identity, alternative)
        @subject.ab_not_showing(experiment, identity)

        assert_equal(
          nil,
          @subject.ab_showing(experiment, identity)
        )
      end
    end
  end
end
