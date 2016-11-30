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
            Vanity.logger.warn("Error while disconnecting from redis: #{e.message}")
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
        single.map { |v| [v.to_i] }
      end

      def destroy_metric(metric)
        @metrics.del(*@metrics.keys("#{metric}:*"))
      end


      # -- Experiments --

      def experiment_persisted?(experiment_id)
        !!@experiments["#{experiment_id}:created_at"]
      end

      def set_experiment_created_at(experiment_id, time)
        call_redis_with_failover do
          @experiments.setnx "#{experiment_id}:created_at", time.to_i
        end
      end

      def get_experiment_created_at(experiment_id)
        created_at = @experiments["#{experiment_id}:created_at"]
        created_at && Time.at(created_at.to_i)
      end

      def set_experiment_completed_at(experiment_id, time)
        @experiments.setnx "#{experiment_id}:completed_at", time.to_i
      end

      def get_experiment_completed_at(experiment_id)
        completed_at = @experiments["#{experiment_id}:completed_at"]
        completed_at && Time.at(completed_at.to_i)
      end

      def is_experiment_completed?(experiment_id)
        call_redis_with_failover do
          @experiments.exists("#{experiment_id}:completed_at")
        end
      end

      def set_experiment_enabled(experiment_id, enabled)
        call_redis_with_failover do
          @experiments.set "#{experiment_id}:enabled", enabled
        end
      end

      def is_experiment_enabled?(experiment_id)
        value = @experiments["#{experiment_id}:enabled"]
        if Vanity.configuration.experiments_start_enabled
          value != 'false'
        else
          value == 'true'
        end
      end

      def ab_counts(experiment, alternative)
        metric_id = experiment.conversion_metric
        {
          :participants => @experiments.scard("#{experiment.id}:alts:#{alternative}:participants").to_i,
          :converted    => @experiments.scard("#{experiment.id}:alts:#{alternative}:metric:#{metric_id}:converted").to_i,
          :conversions  => @experiments["#{experiment.id}:alts:#{alternative}:metric:#{metric_id}:conversions"].to_i
        }
      end

      def ab_counts_by_metric(experiment, alternative)
        counts = {}
        experiment.metrics.each do |metric|
          counts[metric.id] = {
            :converted    => @experiments.scard("#{experiment.id}:alts:#{alternative}:metric:#{metric.id}:converted").to_i,
            :conversions  => @experiments["#{experiment.id}:alts:#{alternative}:metric:#{metric.id}:conversions"].to_i
          }
        end
        counts
      end

      def ab_show(experiment_id, identity, alternative)
        call_redis_with_failover do
          @experiments["#{experiment_id}:participant:#{identity}:show"] = alternative
        end
      end

      def ab_showing(experiment_id, identity)
        call_redis_with_failover do
          alternative = @experiments["#{experiment_id}:participant:#{identity}:show"]
          alternative && alternative.to_i
        end
      end

      def ab_not_showing(experiment_id, identity)
        call_redis_with_failover do
          @experiments.del "#{experiment_id}:participant:#{identity}:show"
        end
      end

      def ab_add_participant(experiment_id, alternative, identity)
        call_redis_with_failover(experiment_id, alternative, identity) do
          @experiments.sadd "#{experiment_id}:alts:#{alternative}:participants", identity
        end
      end

      def ab_seen(experiment_id, identity, alternative_or_id)
        with_ab_seen_deprecation(experiment_id, identity, alternative_or_id) do |expt, ident, alt_id|
          call_redis_with_failover(expt, ident, alt_id) do
            if @experiments.sismember "#{expt}:alts:#{alt_id}:participants", ident
              alt_id
            else
              nil
            end
          end
        end
      end

      # Returns the participant's seen alternative in this experiment, if it exists
      def ab_assigned(experiment_id, identity)
        call_redis_with_failover do
          Vanity.playground.experiments[experiment_id].alternatives.each do |alternative|
            if @experiments.sismember "#{experiment_id}:alts:#{alternative.id}:participants", identity
              return alternative.id
            end
          end
          nil
        end
      end

      def ab_add_conversion(experiment_id, alternative, identity, options={})
        count = options[:count] || 1
        implicit = !!options[:implicit]
        metric_id = options[:metric_id]

        call_redis_with_failover(experiment_id, alternative, identity, count, implicit) do
          if implicit
            ab_add_participant experiment_id, alternative, identity
          else
            participating = @experiments.sismember("#{experiment_id}:alts:#{alternative}:participants", identity)
          end

          if implicit || participating
            @experiments.sadd "#{experiment_id}:alts:#{alternative}:metric:#{metric_id}:converted", identity
            @experiments.incrby "#{experiment_id}:alts:#{alternative}:metric:#{metric_id}:conversions", count
          end
        end
      end

      def ab_get_outcome(experiment_id)
        alternative = @experiments["#{experiment_id}:outcome"]
        alternative && alternative.to_i
      end

      def ab_set_outcome(experiment_id, alternative = 0)
        @experiments.setnx "#{experiment_id}:outcome", alternative
      end

      def destroy_experiment(experiment_id)
        @experiments.del "#{experiment_id}:outcome", "#{experiment_id}:created_at", "#{experiment_id}:completed_at"
        alternatives = @experiments.keys("#{experiment_id}:alts:*")
        @experiments.del(*alternatives) unless alternatives.empty?
      end

      protected

      def call_redis_with_failover(*arguments)
        calling_method = caller[0][/`.*'/][1..-2]
        begin
          yield
        rescue => e
          if Vanity.configuration.failover_on_datastore_error
            Vanity.configuration.on_datastore_error.call(e, self.class, calling_method, arguments)
          else
            raise e
          end
        end
      end
    end
  end
end
