module Vanity
  module Adapters
    def self.redis_connection(spec)
      require "redis"
      RedisAdapter.new(spec)
    end

    class RedisAdapter < AbstractAdapter
      def initialize(options)
        @options = options.clone
        @options[:db] = options[:database] || (options[:path] && options[:path].split("/")[1].to_i)
        @options[:thread_safe] = true
        @redis = ::Redis.new(@options)
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

      def method_missing(*args)
        @redis.send *args
      end
    end
  end
end
