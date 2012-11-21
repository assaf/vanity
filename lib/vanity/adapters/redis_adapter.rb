module Vanity
  module Adapters
    class << self
      # Creates new connection to Redis and returns RedisAdapter.
      #
      # @since 1.4.0
      def redis_connection(spec)
        require "redis/namespace"
        RedisAdapter.new(spec)
      end
    end

    # Redis adapter.
    #
    # @since 1.4.0
    class RedisAdapter < AbstractAdapter
      def initialize(options)
        @options = options.clone
        @options[:db] ||= @options[:database] || (@options[:path] && @options.delete(:path).split("/")[1].to_i)
        @options[:thread_safe] = true
        connect!
      end

      def active?
        !!@redis
      end

      def disconnect!
        if redis
          begin
            redis.client.disconnect
          rescue Exception => e
            warn("Error while disconnecting from redis: #{e.message}")
          end
        end
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
        redis.id
      end

      def redis
        @redis
      end

      def flushdb
        @redis.flushdb
      end

      # -- Metrics --
      
      def get_metric_last_update_at(metric)
        last_update_at = @metrics["#{metric}:last_update_at"]
        last_update_at && Time.at(last_update_at.to_i)
      end

      def metric_track(metric, timestamp, identity, values)
        values.each_with_index do |v,i|
          @metrics.incrby "#{metric}:#{timestamp.to_date}:value:#{i}", v
        end
        @metrics["#{metric}:last_update_at"] = Time.now.to_i
      end

      def metric_values(metric, from, to)
        single = @metrics.mget(*(from.to_date..to.to_date).map { |date| "#{metric}:#{date}:value:0" }) || []
        single.map { |v| [v] }
      end

      def destroy_metric(metric)
        @metrics.del *@metrics.keys("#{metric}:*")
      end


      # -- Experiments --
     
      def set_experiment_enabled(experiment, enabled)
        @experiments.set "#{experiment}:enabled", enabled
      end

      def is_experiment_enabled?(experiment)
        @experiments["#{experiment}:enabled"] == 'true'
      end
     
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
      
      def ab_metric_counts(experiment, alternative)
        metric_count_keys = @experiments.keys("#{experiment}:alts:#{alternative}:metrics:*")
        Hash[metric_count_keys.map {|key| [key.split(':')[4], @experiments[key].to_i]}]
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
          # add participant
          @experiments.sadd "#{experiment}:alts:#{alternative}:participants", identity
          # convert
          @experiments.sadd "#{experiment}:alts:#{alternative}:converted", identity
          @experiments.incrby "#{experiment}:alts:#{alternative}:conversions", count
        elsif @experiments.sismember("#{experiment}:alts:#{alternative}:participants", identity) # is participant?
          # convert
          @experiments.sadd "#{experiment}:alts:#{alternative}:converted", identity
          @experiments.incrby "#{experiment}:alts:#{alternative}:conversions", count
        end
      end

      def ab_add_metric_count(experiment, alternative, metric, count = 1)
        @experiments.incrby "#{experiment}:alts:#{alternative}:metrics:#{metric}:metric_count", count
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
        alternatives = @experiments.keys("#{experiment}:alts:*")
        @experiments.del *alternatives unless alternatives.empty?
      end
    end
  end
end
