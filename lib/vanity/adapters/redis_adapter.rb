module Vanity
  module Adapters
    class << self
      # Creates new connection to Redis and returns RedisAdapter.
      #
      # @since 1.4.0
      def redis_connection(spec)
        require "redis"
        fail "redis >= 2.1 is required" unless valid_redis_version?
        require "redis/namespace"
        fail "redis-namespace >= 1.1.0 is required" unless valid_redis_namespace_version?

        RedisAdapter.new(spec)
      end

      def valid_redis_version?
        Gem.loaded_specs['redis'].version >= Gem::Version.create('2.1')
      end

      def valid_redis_namespace_version?
        Gem.loaded_specs['redis'].version >= Gem::Version.create('1.1.0')
      end
    end

    # Redis adapter.
    #
    # @since 1.4.0
    class RedisAdapter < AbstractAdapter
      attr_reader :redis

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
        @metrics = Redis::Namespace.new("vanity:metrics", :redis=>redis)
        @experiments = Redis::Namespace.new("vanity:experiments", :redis=>redis)
      end

      def to_s
        redis.id
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
        call_redis_with_failover(metric, timestamp, identity, values) do
          values.each_with_index do |v,i|
            @metrics.incrby "#{metric}:#{timestamp.to_date}:value:#{i}", v
          end
          @metrics["#{metric}:last_update_at"] = Time.now.to_i
        end
      end

      def metric_values(metric, from, to)
        single = @metrics.mget(*(from.to_date..to.to_date).map { |date| "#{metric}:#{date}:value:0" }) || []
        single.map { |v| [v] }
      end

      def destroy_metric(metric)
        @metrics.del *@metrics.keys("#{metric}:*")
      end


      # -- Experiments --

      def experiment_persisted?(experiment)
        !!@experiments["#{experiment}:created_at"]
      end

      def set_experiment_created_at(experiment, time)
        call_redis_with_failover do
          @experiments.setnx "#{experiment}:created_at", time.to_i
        end
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
        call_redis_with_failover do
          @experiments.exists("#{experiment}:completed_at")
        end
      end

      def ab_counts(experiment, alternative)
        {
          :participants => @experiments.scard("#{experiment}:alts:#{alternative}:participants").to_i,
                :converted    => @experiments.scard("#{experiment}:alts:#{alternative}:converted").to_i,
          :conversions  => @experiments["#{experiment}:alts:#{alternative}:conversions"].to_i
        }
      end

      def ab_show(experiment, identity, alternative)
        call_redis_with_failover do
          @experiments["#{experiment}:participant:#{identity}:show"] = alternative
        end
      end

      def ab_showing(experiment, identity)
        call_redis_with_failover do
          alternative = @experiments["#{experiment}:participant:#{identity}:show"]
          alternative && alternative.to_i
        end
      end

      def ab_not_showing(experiment, identity)
        call_redis_with_failover do
          @experiments.del "#{experiment}:participant:#{identity}:show"
        end
      end

      def ab_add_participant(experiment, alternative, identity)
        call_redis_with_failover(experiment, alternative, identity) do
          @experiments.sadd "#{experiment}:alts:#{alternative}:participants", identity
        end
      end

      def ab_seen(experiment, identity, alternative)
        call_redis_with_failover(experiment, identity, alternative) do
          if @experiments.sismember "#{experiment}:alts:#{alternative.id}:participants", identity
            alternative
          else
            nil
          end
        end
      end

      # Returns the participant's seen alternative in this experiment, if it exists
      def ab_assigned(experiment, identity)
        call_redis_with_failover do
          Vanity.playground.experiments[experiment].alternatives.each do |alternative|
            if @experiments.sismember "#{experiment}:alts:#{alternative.id}:participants", identity
              return alternative.id
            end
          end
          nil
        end
      end

      def ab_add_conversion(experiment, alternative, identity, count = 1, implicit = false)
        call_redis_with_failover(experiment, alternative, identity, count, implicit) do
          if implicit
            @experiments.sadd "#{experiment}:alts:#{alternative}:participants", identity
          else
            participating = @experiments.sismember("#{experiment}:alts:#{alternative}:participants", identity)
          end
          @experiments.sadd "#{experiment}:alts:#{alternative}:converted", identity if implicit || participating
          @experiments.incrby "#{experiment}:alts:#{alternative}:conversions", count
        end
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

      protected

      def call_redis_with_failover(*arguments)
        calling_method = caller[0][/`.*'/][1..-2]
        begin
          yield
        rescue => e
          if Vanity.playground.failover_on_datastore_error?
            Vanity.playground.on_datastore_error.call(e, self.class, calling_method, arguments)
          else
            raise e
          end
        end
      end
    end
  end
end
