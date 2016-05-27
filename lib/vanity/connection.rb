module Vanity
  # @deprecated This class is a facade into one of the adapters in the
  # Vanity::Adapters namspace, it will be merged into the top level
  # Vanity.connect! helper and/or the adapters.
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
    def initialize(specification=nil)
      @specification = specification || DEFAULT_SPECIFICATION

      @adapter = adapter_from_specification(@specification)
      connect!
    end

    # Closes the current connection.
    #
    # @since 2.0.0
    def disconnect!
      @adapter.disconnect! if connected?
    end

    # Creates a connection.
    #
    # @since 2.2.2
    def connect!
      @adapter && @adapter.connect!
    end

    # Returns true if connection is open.
    #
    # @since 2.0.0
    def connected?
      @adapter && @adapter.active?
    end

    private

    def adapter_from_specification(spec)
      case spec
      when String
        spec_hash = specification_hash_from_url(spec)
        initialize_adapter(spec_hash)
      when Hash
        validate_specification_hash(spec)
        if spec[:redis]
          initialize_adapter(
            adapter: :redis,
            redis: spec[:redis]
          )
        else
          initialize_adapter(spec)
        end
      else
        raise InvalidSpecification.new("Unsupported connection specification: #{spec.inspect}")
      end
    end

    def specification_hash_from_url(connection_url)
      uri = URI.parse(connection_url)
      params = CGI.parse(uri.query) if uri.query
      {
        adapter: uri.scheme,
        username: uri.user,
        password: uri.password,
        host: uri.host,
        port: uri.port,
        path: uri.path,
        params: params
      }
    end

    def validate_specification_hash(spec)
      all_symbol_keys = spec.keys.all? { |key| key.is_a?(Symbol) }
      raise InvalidSpecification unless all_symbol_keys
    end

    def initialize_adapter(spec)
      begin
        require "vanity/adapters/#{spec[:adapter]}_adapter"
      rescue LoadError
        raise "Could not find #{spec[:adapter]} in your load path"
      end

      klass = spec[:adapter].to_s.split('_').collect(&:capitalize).join
      # Get the class constant directly from the module instead of chaining
      # the constant with `::` to avoid breaking on jruby in 1
      Vanity::Adapters.const_get("#{klass}Adapter").new(spec)
    end
  end
end