module Vanity
  # This class holds the "how" Vanity operates. For the "what", please see
  # Vanity::Playground.
  class Configuration
    class MissingEnvironment < StandardError; end

    LEGACY_REDIS_CONFIG_FILE = "redis.yml"

    class<<self
      private

      def default_logger # :nodoc:
        logger = Logger.new(STDOUT)
        logger.level = Logger::WARN
        logger
      end

      def default_on_datastore_error(error, klass, method, arguments) # :nodoc:
        log = "[#{Time.now.iso8601}]"
        log << " [vanity #{klass} #{method}]"
        log << " [#{error.message}]"
        log << " [#{arguments.join(' ')}]"
        Vanity.logger.error(log)
        nil
      end

      def default_request_filter(request) # :nodoc:
        request &&
          request.env &&
          request.env["HTTP_USER_AGENT"] &&
          request.env["HTTP_USER_AGENT"].match(/\(.*https?:\/\/.*\)/)
      end
    end

    DEFAULTS = {
      collecting: true,
      experiments_path: File.join(Pathname.new("."), "experiments"),
      add_participant_route: "/vanity/add_participant",
      logger: default_logger,
      failover_on_datastore_error: false,
      on_datastore_error: ->(error, klass, method, arguments) {
        default_on_datastore_error(error, klass, method, arguments)
      },
      request_filter: ->(request) { default_request_filter(request) },
      templates_path: File.expand_path(File.join(File.dirname(__FILE__), 'templates')),
      locales_path: File.expand_path(File.join(File.dirname(__FILE__), 'locales')),
      use_js: false,
      config_path: File.join(Pathname.new("."), "config"),
      config_file: "vanity.yml",
      environment: ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
    }.freeze

    # True if saving results to the datastore (participants and conversions).
    attr_writer :collecting

    # Path to load experiment files from.
    attr_writer :experiments_path

    # URL to the add_participant action.
    attr_writer :add_participant_route

    # Logger. The default logs to STDOUT.
    attr_writer :logger

    # -- Datastore graceful failover --

    # Turns on passing of errors to the Proc returned by #on_datastore_error.
    # Set `config.failover_on_datastore_error` to `true` to turn this on.
    #
    # @since 2.0.0
    attr_writer :failover_on_datastore_error

    # Must return a Proc that accepts as parameters: the thrown error, the
    # calling Class, the calling method, and an array of arguments passed to
    # the calling method. The return value is ignored.
    #
    # @example
    #    Proc.new do |error, klass, method, arguments|
    #      ...
    #    end
    #
    # The default implementation logs this information to Playground#logger.
    #
    # Set a custom action by calling config.on_datastore_error =
    # Proc.new { ... }.
    #
    # @since 2.0.0
    attr_writer :on_datastore_error

    # -- Blocking or ignoring visitors --

    # Must return a Proc that accepts as a parameter the request object, if
    # made available by the implement framework. The return value should be a
    # boolean whether to ignore the request. This is called only for the JS
    # callback action.
    #
    # @example
    #    Proc.new do |request|
    #      ...
    #    end
    #
    # The default implementation does a simple test of whether the request's
    # HTTP_USER_AGENT header contains a URI, since well behaved bots typically
    # include a reference URI in their user agent strings. (Original idea:
    # http://stackoverflow.com/a/9285889.)
    #
    # Alternatively, one could filter an explicit list of IPs, add additional
    # user agent strings to filter, or any custom test. Set a custom filter
    # by calling config.request_filter = Proc.new { ... }.
    #
    # @since 2.0.0
    attr_writer :request_filter

    # Path to Vanity templates. Set this to override those in the gem.
    attr_writer :templates_path

    # Path to Vanity locales. Set this to override those in the gem.
    attr_writer :locales_path

    # -- Robot Detection --

    # Call to indicate that participants should be added via js. This helps
    # keep robots from participating in the A/B test and skewing results.
    #
    # If you want to use this:
    # - Add <%= vanity_js %> to any page that needs uses an ab_test. vanity_js
    #   needs to be included after your call to ab_test so that it knows which
    #   version of the experiment the participant is a member of. The helper
    #   will render nothing if the there are no ab_tests running on the current
    #   page, so adding vanity_js to the bottom of your layouts is a good
    #   option. Keep in mind that if you set config.use_js = true and don't include
    #   vanity_js in your view no participants will be recorded.
    #
    # Note that a custom JS callback path can be set using:
    # - Set config.add_participant_route = '/path/to/vanity/action',
    #   this should point to the add_participant path that is added with
    #   Vanity::Rails::Dashboard, make sure that this action is available
    #   to all users.
    attr_writer :use_js
    # Uses ./config by default.
    attr_writer :config_path
    # By default the vanity.yml file in the config_path variable. Variables
    # scoped under the key for the current environment are extracted for the
    # connection parameters. If there is no config/vanity.yml file, tries the
    # configuration from config/redis.yml.
    attr_writer :config_file
    # In order of precedence, RACK_ENV, RAILS_ENV or `development`.
    attr_writer :environment


    # We independently list each attr_accessor to includes docs, otherwise
    # something like DEFAULTS.each { |key, value| attr_accessor key } would be
    # shorter.
    DEFAULTS.each do |default, value|
      define_method default do
        self[default]
      end
    end

    def [](arg)
      if instance_variable_defined?("@#{arg}")
        instance_variable_get("@#{arg}")
      else
        DEFAULTS[arg]
      end
    end

    def setup_locales
      locales = Dir[File.join(locales_path, '*.{rb,yml}')]
      I18n.load_path += locales
    end

    # @return nil or a hash of symbolized keys for connection settings
    def connection_params(file_name=nil)
      file_name ||= config_file
      file_path = File.join(config_path, file_name)

      if File.exists?(file_path)
        config = YAML.load(ERB.new(File.read(file_path)).result)
        config ||= {}
        params_for_environment = config[environment.to_s]

        unless params_for_environment
          raise MissingEnvironment.new("No configuration for #{environment}")
        end

        # Symbolize keys if it's a hash.
        if params_for_environment.respond_to?(:inject)
          params_for_environment.inject({}) { |h,kv| h[kv.first.to_sym] = kv.last ; h }
        else
          params_for_environment
        end
      end
    end

    # @deprecated
    def redis_url_from_file
      connection_url = connection_params(LEGACY_REDIS_CONFIG_FILE)

      if connection_url
        logger.warn(%q{Deprecated: Please specify the vanity config file, the default fallback to "config/redis.yml" may be removed in a future version.})

        if connection_url =~ /^\w+:/
          connection_url
        else
          "redis://" + connection_url
        end
      end
    end
  end
end