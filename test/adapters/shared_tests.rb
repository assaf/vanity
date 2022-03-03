require 'time'

module Vanity::Adapters::SharedTests
  DummyAlternative = Struct.new(:id)

  def identity
    'test-identity'
  end

  def experiment
    :experiment
  end

  def alternative
    1
  end

  def metric_name
    :purchases
  end

  def run_experiment
    @subject.ab_add_participant(experiment, alternative, identity)
    @subject.ab_add_participant(experiment, alternative, 'other-identity')
    @subject.ab_add_conversion(experiment, alternative, identity, 2)
  end

  def self.included(base)
    base.instance_eval do
      before do
        @subject = adapter
        @subject.flushdb

        metric "purchases"

        new_ab_test "experiment" do
          alternatives :control, :test
          default :control
          metrics :purchases
        end
      end

      describe 'metrics methods' do
        describe '#get_metric_last_update_at' do
          it 'is nil if the metric has never been tracked' do
            refute(@subject.get_metric_last_update_at(metric_name))
          end

          it 'returns the time of the last tracked event if present' do
            time = Time.now
            @subject.metric_track(metric_name, time, identity, [1])

            assert_in_delta(
              time,
              @subject.get_metric_last_update_at(metric_name),
              1.0
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

            @subject.metric_track(metric_name, time_1, identity, [1])
            @subject.metric_track(metric_name, time_2, identity, [2])
            @subject.metric_track(metric_name, time_3, identity, [4])
            @subject.metric_track(metric_name, time_4, identity, [8])
            @subject.metric_track(metric_name, time_5, identity, [16])

            assert_equal(
              [[3], [12]],
              @subject.metric_values(metric_name, time_1, time_4)
            )
          end
        end

        describe '#destroy_metric' do
          it 'removes all data related to the metric' do
            @subject.metric_track(metric_name, Time.now, identity, [1])

            @subject.destroy_metric(metric_name)

            refute(@subject.get_metric_last_update_at(metric_name))
          end
        end
      end

      describe 'generic experiment methods' do
        describe '#experiment_persisted?' do
          it 'returns false if the experiment is unknown' do
            refute(@subject.experiment_persisted?("other_experiment"))
          end

          it 'returns true if the experiment has been created' do
            @subject.set_experiment_created_at("other_experiment", Time.now)

            assert(@subject.experiment_persisted?("other_experiment"))
          end
        end

        describe '#set_experiment_created_at' do
          it 'sets the experiment creation date' do
            time = Time.now
            @subject.set_experiment_created_at(experiment, time)

            assert_in_delta(
              time,
              @subject.get_experiment_created_at(experiment),
              1.0
            )
          end
        end

        describe '#destroy_experiment' do
          it 'removes all information about the experiment' do
            run_experiment
            @subject.destroy_experiment(experiment)

            refute(@subject.experiment_persisted?(experiment))
            assert_equal(
              { participants: 0, converted: 0, conversions: 0 },
              @subject.ab_counts(experiment, alternative)
            )
          end
        end

        describe '#is_experiment_enabled?' do
          def with_experiments_start_enabled(enabled)
            original_value = Vanity.configuration.experiments_start_enabled
            Vanity.configuration.experiments_start_enabled = enabled
            yield
          ensure
            Vanity.configuration.experiments_start_enabled = original_value
          end

          describe 'when experiments start enabled' do
            it 'is true when the enabled value is unset' do
              with_experiments_start_enabled(true) do
                assert(@subject.is_experiment_enabled?("other_experiment"))
              end
            end

            it 'is false when the enabled value is set to false' do
              with_experiments_start_enabled(true) do
                @subject.set_experiment_enabled("other_experiment", false)

                refute(@subject.is_experiment_enabled?("other_experiment"))
              end
            end
          end

          describe 'when experiments do not start enabled' do
            it 'is false when the enabled value is unset' do
              with_experiments_start_enabled(false) do
                refute(@subject.is_experiment_enabled?("other_experiment"))
              end
            end

            it 'is true when the enabled value is set to true' do
              with_experiments_start_enabled(false) do
                @subject.set_experiment_enabled("other_experiment", true)

                assert(@subject.is_experiment_enabled?("other_experiment"))
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
              { participants: 1, conversions: 1, converted: 1 },
              @subject.ab_counts(experiment, alternative)
            )
          end
        end

        describe '#ab_add_participant' do
          it 'adds the participant to the specified alternative' do
            @subject.ab_add_participant(experiment, alternative, identity)

            assert_equal(
              { participants: 1, conversions: 0, converted: 0 },
              @subject.ab_counts(experiment, alternative)
            )
          end
        end

        describe '#ab_seen' do
          describe 'called with an Alternative instance' do
            def capture_logs
              require 'stringio'
              original_logger = Vanity.configuration.logger
              log_output = StringIO.new
              Vanity.configuration.logger = Logger.new(log_output)
              yield
              log_output.string
            ensure
              Vanity.configuration.logger = original_logger
            end

            before do
              @alternative_instance = DummyAlternative.new(alternative)
            end

            it 'emits a deprecation warning' do
              @subject.ab_add_participant(experiment, alternative, identity)

              out = capture_logs do
                @subject.ab_seen(experiment, identity, @alternative_instance)
              end

              assert_match(/Deprecated/, out)
            end

            it 'returns a truthy value if the identity is assigned to the alternative' do
              @subject.ab_add_participant(experiment, alternative, identity)

              assert(@subject.ab_seen(experiment, identity, @alternative_instance))
            end

            it 'returns a falsey value if the identity is not assigned to the alternative' do
              @subject.ab_add_participant(experiment, alternative, identity)

              refute(@subject.ab_seen(experiment, identity, DummyAlternative.new(2)))
            end
          end

          describe 'called with an alternative id' do
            it 'returns a truthy value if the identity is assigned to the alternative' do
              @subject.ab_add_participant(experiment, alternative, identity)

              assert(@subject.ab_seen(experiment, identity, alternative))
            end

            it 'returns a falsey value if the identity is not assigned to the alternative' do
              @subject.ab_add_participant(experiment, alternative, identity)

              refute(@subject.ab_seen(experiment, identity, 2))
            end
          end
        end

        describe '#ab_assigned' do
          it 'returns the assigned alternative if present' do
            @subject.ab_add_participant(experiment, alternative, identity)

            assert_equal(
              alternative,
              @subject.ab_assigned(experiment, identity)
            )
          end

          it 'returns nil if the identity has no assignment' do
            assert_nil(
              @subject.ab_assigned(experiment, identity)
            )
          end
        end

        describe '#ab_counts' do
          it 'returns the counts of participants, conversions and converted for the alternative' do
            run_experiment

            assert_equal(
              { participants: 2, conversions: 2, converted: 1 },
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
            assert_nil(
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

            assert_nil(
              @subject.ab_showing(experiment, identity)
            )
          end
        end
      end
    end
  end
end
