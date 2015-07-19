#
# Run time configuration and helpers
#
module Vanity
  # Returns the current configuration.
  #
  # @see Vanity::Configuration
  # @since 2.0.0
  def self.configuration(set_if_needed=true)
    if @configuration
      @configuration
    elsif set_if_needed
      configure!
    end
  end

  # @since 2.0.0
  def self.configure!
    @configuration = Configuration.new
  end

  # @since 2.0.0
  def self.reset!
    @configuration = nil
    configuration
  end

  # This is the preferred way to configure Vanity.
  #
  # @example
  #   Vanity.configure do |config|
  #     config.use_js = true
  #   end
  # @since 2.0.0
  def self.configure
    yield(configuration)
  end

  # @since 2.0.0
  def self.logger
    configuration.logger
  end

  # Returns the Vanity context. For example, when using Rails this would be
  # the current controller, which can be used to get/set the vanity identity.
  def self.context
    Thread.current[:vanity_context]
  end

  # Sets the Vanity context. For example, when using Rails this would be
  # set by the set_vanity_context before filter (via Vanity::Rails#use_vanity).
  def self.context=(context)
    Thread.current[:vanity_context] = context
  end

  #
  # Datastore connection management
  #

  # Returns the current connection. Establishes new connection is necessary.
  #
  # @since 2.0.0
  def self.connection(connect_if_needed=true)
    if @connection
      @connection
    elsif connect_if_needed
      connect!
    end
  end

  # This is the preferred way to programmatically create a new connection (or
  # switch to a new connection). If no connection was established, the
  # playground will create a new one by calling this method with no arguments.
  #
  # @since 2.0.0
  # @see Vanity::Connection
  def self.connect!(spec_or_nil=nil)
    spec_or_nil ||= configuration.connection_params

    # Legacy redis.yml fallback
    if spec_or_nil.nil?
      redis_url = configuration.redis_url_from_file

      if redis_url
        spec_or_nil = redis_url
      end
    end

    # Legacy special config variables permitted in connection spec
    update_configuration_from_connection_params(spec_or_nil)

    @connection = Connection.new(spec_or_nil)
  end

  # Destroys a connection
  #
  # @since 2.0.0
  def self.disconnect!
    if @connection
      @connection.disconnect!
      @connection = nil
    end
  end

  def self.reconnect!
    disconnect!
    connect!
  end

  #
  # Experiment metadata
  #

  # The playground instance.
  #
  # @see Vanity::Playground
  def self.playground(load_if_needed=true)
    if @playground
      @playground
    elsif load_if_needed
      load!
    end
  end

  # Loads all metrics and experiments. Called during initialization. In the
  # case of Rails, use the Rails logger and look for templates at
  # app/views/vanity.
  #
  # @since 2.0.0
  def self.load!
    @playground = Playground.new
  end

  # @since 2.0.0
  def self.unload!
    @playground = nil
  end

  # Reloads all metrics and experiments. Rails calls this for each request in
  # development mode.
  #
  # @since 2.0.0
  def self.reload!
    unload!
    load!
  end

  class << self
    # @since 2.0.0
    attr_writer :configuration

    # @since 2.0.0
    attr_writer :playground

    # @since 2.0.0
    attr_writer :connection

    private

    def update_configuration_from_connection_params(spec_or_nil) # # :nodoc:
      return unless spec_or_nil.respond_to?(:has_key?)

      configuration.collecting = spec_or_nil[:collecting] if spec_or_nil.has_key?(:collecting)
    end
  end
end