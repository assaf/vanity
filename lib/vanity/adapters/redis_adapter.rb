module Vanity
  module Adapters
    class << self
      def redis_connection(spec)
        require "redis"
        RedisAdapter.new(spec)
      end
    end

    class RedisAdapter < AbstractAdapter
      def initialize(options)
        @options = options.clone
        @options[:db] = options[:database] || (options[:path] && options[:path].split("/")[1].to_i)
        @options[:thread_safe] = true
        @redis = options[:redis] || ::Redis.new(@options)
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
        @redis = ::Redis.new(@options)
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
        @redis.setnx metric_key(metric, :created_at), time.to_i
      end

      def get_metric_created_at(metric)
        created_at = @redis[metric_key(metric, :created_at)]
        created_at && Time.at(created_at.to_i)
      end

      def metric_track(metric, time, count = 1)
        @redis.incrby metric_key(metric, time.to_date, "count"), count
      end

      def metric_values(metric, from, to)
        @redis.mget(*(from.to_date..to.to_date).map { |date| metric_key(metric, date, "count") }) || []
      end

      def destroy_metric(metric)
        @redis.del *@redis.keys(metric_key(metric, "*"))
      end

      # -- Experiments --
     
      def set_experiment_created_at(experiment, time)
        @redis.setnx ab_key(experiment, :created_at), time.to_i
      end

      def get_experiment_created_at(experiment)
        created_at = @redis[ab_key(experiment, :created_at)]
        created_at && Time.at(created_at.to_i)
      end

      def set_experiment_completed_at(experiment, time)
        @redis.setnx ab_key(experiment, :completed_at), time.to_i
      end

      def get_experiment_completed_at(experiment)
        completed_at = @redis[ab_key(experiment, :completed_at)]
        completed_at && Time.at(completed_at.to_i)
      end

      def is_experiment_completed?(experiment)
        @redis.exists(ab_key(experiment, :completed_at))
      end

      def ab_counts(experiment, alternative)
        { :participants => @redis.scard(ab_key(experiment, "alts", alternative, "participants")).to_i,
          :converted    => @redis.scard(ab_key(experiment, "alts", alternative, "converted")).to_i,
          :conversions  => @redis[ab_key(experiment, "alts", alternative, "conversions")].to_i }
      end

      def ab_show(experiment, identity, alternative)
        @redis[ab_key(experiment, "participant", identity, "show")] = alternative
      end

      def ab_showing(experiment, identity)
        alternative = @redis[ab_key(experiment, "participant", identity, "show")]
        alternative && alternative.to_i
      end

      def ab_not_showing(experiment, identity)
        @redis.del ab_key(experiment, "participant", identity, "show")
      end

      def ab_add_participant(experiment, alternative, identity)
        @redis.sadd ab_key(experiment, "alts", alternative, "participants"), identity
      end

      def ab_add_conversion(experiment, alternative, identity, count = 1, implicit = false)
        if implicit
          @redis.sadd ab_key(experiment, "alts", alternative, "participants"), identity
        else
          participating = @redis.sismember(ab_key(experiment, "alts", alternative, "participants"), identity)
        end
        @redis.sadd ab_key(experiment, "alts", alternative, "converted"), identity if implicit || participating
        @redis.incrby ab_key(experiment, "alts", alternative, "conversions"), count
      end

      def ab_get_outcome(experiment)
        alternative = @redis[ab_key(experiment, :outcome)]
        alternative && alternative.to_i
      end

      def ab_set_outcome(experiment, alternative = 0)
        @redis.setnx ab_key(experiment, :outcome), alternative
      end

      def destroy_experiment(experiment)
        @redis.del ab_key(experiment, :outcome), ab_key(experiment, :created_at), ab_key(experiment, :completed_at)
        @redis.del *@redis.keys(ab_key(experiment, "alts:*"))
      end

     protected

      def metric_key(metric, *args)
        "metrics:#{metric}:#{args.join(':')}"
      end

      def ab_key(experiment, *args)
        base = "vanity:#{Vanity::Version::MAJOR}:#{experiment}"
        args.empty? ? base : "#{base}:#{args.join(":")}"
      end

    end
  end
end
