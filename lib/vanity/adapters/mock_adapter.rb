module Vanity
  module Adapters

    class << self
      def mock_connection(spec)
        MockAdapter.new(spec)
      end

    end

    class MockAdapter < AbstractAdapter
      def initialize(options)
        @metrics = @@metrics ||= {}
        @experiments = @@experiments ||= {}
      end

      def active?
        !!@metrics
      end

      def disconnect!
        @metrics = nil
        @experiments = nil
      end

      def reconnect!
        @metrics = @@metrics
        @experiments = @@experiments
      end

      def to_s
        "mock:/"
      end

      def flushdb
        @metrics.clear
        @experiments.clear
      end

      # -- Metrics --
      
      def set_metric_created_at(metric, time)
        @metrics[metric] ||= {}
        @metrics[metric][:created_at] ||= time
      end

      def get_metric_created_at(metric)
        @metrics[metric] && @metrics[metric][:created_at]
      end

      def metric_track(metric, time, count = 1)
        @metrics[metric] ||= {}
        @metrics[metric][time.to_date] ||= 0
        @metrics[metric][time.to_date] += count
      end

      def metric_values(metric, from, to)
        hash = @metrics[metric] || {}
        (from.to_date..to.to_date).map { |date| hash[date] || 0 }
      end

      def destroy_metric(metric)
        @metrics.delete metric
      end
      
      # -- Experiments --
     
      def set_experiment_created_at(experiment, time)
        @experiments[experiment] ||= {}
        @experiments[experiment][:created_at] ||= time
      end

      def get_experiment_created_at(experiment)
        @experiments[experiment] && @experiments[experiment][:created_at]
      end

      def set_experiment_completed_at(experiment, time)
        @experiments[experiment] ||= {}
        @experiments[experiment][:completed_at] ||= time
      end

      def get_experiment_completed_at(experiment)
        @experiments[experiment] && @experiments[experiment][:completed_at]
      end

      def is_experiment_completed?(experiment)
        @experiments[experiment] && @experiments[experiment][:completed_at]
      end

      def ab_counts(experiment, alternative)
        @experiments[experiment] ||= {}
        @experiments[experiment][:alternatives] ||= {}
        alt = @experiments[experiment][:alternatives][alternative] ||= {}
        { :participants => alt[:participants] ? alt[:participants].size : 0,
          :converted    => alt[:converted] ? alt[:converted].size : 0,
          :conversions  => alt[:conversions] || 0 }
      end

      def ab_show(experiment, identity, alternative)
        @experiments[experiment] ||= {}
        @experiments[experiment][:showing] ||= {}
        @experiments[experiment][:showing][identity] = alternative
      end

      def ab_showing(experiment, identity)
        @experiments[experiment] && @experiments[experiment][:showing] && @experiments[experiment][:showing][identity]
      end

      def ab_not_showing(experiment, identity)
        @experiments[experiment][:showing].delete identity if @experiments[experiment] && @experiments[experiment][:showing]
      end

      def ab_add_participant(experiment, alternative, identity)
        @experiments[experiment] ||= {}
        @experiments[experiment][:alternatives] ||= {}
        alt = @experiments[experiment][:alternatives][alternative] ||= {}
        alt[:participants] ||= Set.new
        alt[:participants] << identity
      end

      def ab_add_conversion(experiment, alternative, identity, count = 1, implicit = false)
        @experiments[experiment] ||= {}
        @experiments[experiment][:alternatives] ||= {}
        alt = @experiments[experiment][:alternatives][alternative] ||= {}
        alt[:participants] ||= Set.new
        alt[:converted] ||= Set.new
        alt[:conversions] ||= 0
        if implicit
          alt[:participants] << identity
        else
          participating = alt[:participants].include?(identity) 
        end
        alt[:converted] << identity if implicit || participating
        alt[:conversions] += count
      end

      def ab_get_outcome(experiment)
        @experiments[experiment] ||= {}
        @experiments[experiment][:outcome]
      end

      def ab_set_outcome(experiment, alternative = 0)
        @experiments[experiment] ||= {}
        @experiments[experiment][:outcome] = alternative
      end

      def destroy_experiment(experiment)
        @experiments.delete experiment
      end
    end
  end
end
