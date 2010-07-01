module Vanity
  module Adapters
    class << self
      def redis_connection(spec)
        require "redis/namespace"
        RedisAdapter.new(spec)
      end
    end

    class RedisAdapter < AbstractAdapter
      def initialize(options)
        @options = options.clone
        @options[:db] = @options[:database] || (@options[:path] && @options[:path].split("/")[1].to_i)
        @options[:thread_safe] = true
        connect!
      end

      def active?
        !!@redis
      end

      def disconnect!
        @redis.quit rescue nil if @redis
        @redis = nil
      end

      def reconnect!
        disconnect!
        connect!
      end

      def connect!
        @redis = @options[:redis] || Redis.new(@options)
        @metrics = Redis::Namespace.new("vanity:metrics", :redis=>@redis)
        @experiments = Redis::Namespace.new("vanity:experiments", :redis=>@redis)
      end

      def to_s
        @redis.id
      end

      def redis
        @redis
      end

      def flushdb
        @redis.flushdb
      end

      # -- Metrics --
      
      def set_metric_created_at(metric, time)
        @metrics.setnx "#{metric}:created_at", time.to_i
      end

      def get_metric_created_at(metric)
        created_at = @metrics["#{metric}:created_at"]
        created_at && Time.at(created_at.to_i)
      end

      def metric_track(metric, time, count = 1)
        @metrics.incrby "#{metric}:#{time.to_date}:count", count
      end

      def metric_values(metric, from, to)
        @metrics.mget(*(from.to_date..to.to_date).map { |date| "#{metric}:#{date}:count" }) || []
      end

      def destroy_metric(metric)
        @metrics.del *@metrics.keys("#{metric}:*")
      end

      # -- Experiments --
     
      def set_experiment_created_at(experiment, time)
        @experiments.setnx "#{experiment}:created_at", time.to_i
      end

      def get_experiment_created_at(experiment)
        created_at = @experiments["#{experiment}:created_at"]
        created_at && Time.at(created_at.to_i)
      end

      def set_experiment_completed_at(experiment, time)
        @experiments.setnx "#{experiment}:completed_at", time.to_i
      end

      def get_experiment_completed_at(experiment)
        completed_at = @experiments["#{experiment}:completed_at"]
        completed_at && Time.at(completed_at.to_i)
      end

      def is_experiment_completed?(experiment)
        @experiments.exists("#{experiment}:completed_at")
      end

      def ab_counts(experiment, alternative)
        { :participants => @experiments.scard("#{experiment}:alts:#{alternative}:participants").to_i,
          :converted    => @experiments.scard("#{experiment}:alts:#{alternative}:converted").to_i,
          :conversions  => @experiments["#{experiment}:alts:#{alternative}:conversions"].to_i }
      end

      def ab_show(experiment, identity, alternative)
        @experiments["#{experiment}:participant:#{identity}:show"] = alternative
      end

      def ab_showing(experiment, identity)
        alternative = @experiments["#{experiment}:participant:#{identity}:show"]
        alternative && alternative.to_i
      end

      def ab_not_showing(experiment, identity)
        @experiments.del "#{experiment}:participant:#{identity}:show"
      end

      def ab_add_participant(experiment, alternative, identity)
        @experiments.sadd "#{experiment}:alts:#{alternative}:participants", identity
      end

      def ab_add_conversion(experiment, alternative, identity, count = 1, implicit = false)
        if implicit
          @experiments.sadd "#{experiment}:alts:#{alternative}:participants", identity
        else
          participating = @experiments.sismember("#{experiment}:alts:#{alternative}:participants", identity)
        end
        @experiments.sadd "#{experiment}:alts:#{alternative}:converted", identity if implicit || participating
        @experiments.incrby "#{experiment}:alts:#{alternative}:conversions", count
      end

      def ab_get_outcome(experiment)
        alternative = @experiments["#{experiment}:outcome"]
        alternative && alternative.to_i
      end

      def ab_set_outcome(experiment, alternative = 0)
        @experiments.setnx "#{experiment}:outcome", alternative
      end

      def destroy_experiment(experiment)
        @experiments.del "#{experiment}:outcome", "#{experiment}:created_at", "#{experiment}:completed_at"
        @experiments.del *@experiments.keys("#{experiment}:alts:*")
      end

    end
  end
end
