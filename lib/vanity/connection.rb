module Vanity
  class Connection
    class InvalidSpecification < StandardError; end

    DEFAULT_SPECIFICATION = { adapter: "redis" }

    attr_reader :adapter, :specification

    # With no argument, uses the connection specified in the configuration
    # file, or defaults to Redis on localhost, port 6379.
    # @example
    #   Vanity::Connection.new
    #
    # If the argument is a string, it is processed as a URL.
    # @example
    #   Vanity::Connection.new("redis://redis.local/5")
    #
    # If the argument is a Hash, and contains a key `:redis` the value is used
    # as a redis connection.
    # @example
    #   $shared_redis_connection = Redis.new
    #   Vanity::Connection.new(adapter: :redis, redis: $shared_redis_connection)
    #
    # Otherwise, the argument is a hash and specifies the adapter name and any
    # additional options understood by that adapter (as with
    # config/vanity.yml). Note that all keys are expected to be symbols.
    # @example
    #   Vanity::Connection.new(
    #     :adapter=>:redis,
    #     :host=>"redis.local"
    #   )
    # @since 2.0.0
    def initialize(specification = nil)
      @specification = Specification.new(specification || DEFAULT_SPECIFICATION).to_h

      @adapter = setup_connection(@specification) if Autoconnect.playground_should_autoconnect?
    end

    # Closes the current connection.
    #
    # @since 2.0.0
    def disconnect!
      @adapter.disconnect! if connected?
    end

    # Returns true if connection is open.
    #
    # @since 2.0.0
    def connected?
      @adapter && @adapter.active?
    end

    private

    def setup_connection(specification)
      establish_connection(specification)
    end

    def establish_connection(spec)
      Adapters.establish_connection(spec)
    end

    class Specification
      def initialize(spec)
        case spec
        when String
          @spec = build_specification_hash_from_url(spec)
        when Hash
          @spec = if spec[:redis]
                    {
                      adapter: :redis,
                      redis: spec[:redis],
                    }
                  else
                    spec
                  end
        else
          raise InvalidSpecification, "Unsupported connection specification: #{spec.inspect}"
        end

        validate_specification_hash(@spec)
      end

      def to_h
        @spec
      end

      private

      def validate_specification_hash(spec)
        all_symbol_keys = spec.keys.all? { |key| key.is_a?(Symbol) }
        raise InvalidSpecification unless all_symbol_keys
      end

      def build_specification_hash_from_url(connection_url)
        uri = URI.parse(connection_url)
        params = CGI.parse(uri.query) if uri.query
        {
          adapter: uri.scheme,
          username: uri.user,
          password: uri.password,
          host: uri.host,
          port: uri.port,
          path: uri.path,
          params: params,
        }
      end
    end
  end
end
