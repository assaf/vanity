module Vanity

  # A metric is an object that implements two methods: +name+ and +values+. It
  # can also respond to addition methods (+track!+, +bounds+, etc), these are
  # optional.
  #
  # This class implements a basic metric that tracks data and stores it in the
  # database. You can use this as the basis for your metric, or as reference
  # for the methods your metric must and can implement.
  #
  # @since 1.1.0
  class Metric

    # These methods are available when defining a metric in a file loaded
    # from the +experiments/metrics+ directory.
    #
    # For example:
    #   $ cat experiments/metrics/yawn_sec
    #   metric "Yawns/sec" do
    #     description "Most boring metric ever"
    #   end
    module Definition

      attr_reader :playground

      # Defines a new metric, using the class Vanity::Metric.
      def metric(name, &block)
        fail "Metric #{@metric_id} already defined in playground" if playground.metrics[@metric_id]
        metric = Metric.new(playground, name.to_s, @metric_id)
        metric.instance_eval(&block)
        playground.metrics[@metric_id] = metric
      end

      def new_binding(playground, id)
        @playground, @metric_id = playground, id
        binding
      end

    end

    # Startup metrics for pirates. AARRR stands for:
    # * Acquisition
    # * Activation
    # * Retention
    # * Referral
    # * Revenue
    # Read more: http://500hats.typepad.com/500blogs/2007/09/startup-metrics.html
    class << self

      # Helper method to return description for a metric.
      #
      # A metric object may have a +description+ method that returns a detailed
      # description. It may also have no description, or no +description+
      # method, in which case return +nil+.
      #
      # @example
      #   puts Vanity::Metric.description(metric)
      def description(metric)
        metric.description if metric.respond_to?(:description)
      end

      # Helper method to return bounds for a metric.
      #
      # A metric object may have a +bounds+ method that returns lower and upper
      # bounds. It may also have no bounds, or no +bounds+ # method, in which
      # case we return +[nil, nil]+.
      #
      # @example
      #   upper = Vanity::Metric.bounds(metric).last
      def bounds(metric)
        metric.respond_to?(:bounds) && metric.bounds || [nil, nil]
      end

      # Returns data set for a given date range. The data set is an array of
      # date, value pairs.
      #
      # First argument is the metric. Second argument is the start date, or
      # number of days to go back in history, defaults to 90 days. Third
      # argument is end date, defaults to today.
      #
      # @example These are all equivalent:
      #   Vanity::Metric.data(my_metric)
      #   Vanity::Metric.data(my_metric, 90)
      #   Vanity::Metric.data(my_metric, Date.today - 89)
      #   Vanity::Metric.data(my_metric, Date.today - 89, Date.today)
      def data(metric, *args)
        first = args.shift || 90
        to = args.shift || Date.today
        from = first.respond_to?(:to_date) ? first.to_date : to - (first - 1)
        (from..to).zip(metric.values(from, to))
      end

      # Playground uses this to load metric definitions.
      def load(playground, stack, file)
        fail "Circular dependency detected: #{stack.join('=>')}=>#{file}" if stack.include?(file)
        source = File.read(file)
        stack.push file
        id = File.basename(file, ".rb").downcase.gsub(/\W/, "_").to_sym
        context = Object.new
        context.instance_eval do
          extend Definition
          metric = eval(source, context.new_binding(playground, id), file)
          fail NameError.new("Expected #{file} to define metric #{id}", id) unless playground.metrics[id]
          metric
        end
      rescue
        error = NameError.exception($!.message, id)
        error.set_backtrace $!.backtrace
        raise error
      ensure
        stack.pop
      end

    end


    # Takes playground (need this to access Redis), friendly name and optional
    # id (can infer from name).
    def initialize(playground, name, id = nil)
      @playground, @name = playground, name.to_s
      @id = (id || name.to_s.downcase.gsub(/\W+/, '_')).to_sym
      @hooks = []
    end


    # -- Tracking --

    # Called to track an action associated with this metric. Most common is not
    # passing an argument, and it tracks a count of 1. You can pass a different
    # value as the argument, or array of value (for multi-series metrics), or
    # hash with the optional keys timestamp, identity and values.
    #
    # Example:
    #   hits.track!
    #   foo_and_bar.track! [5,11]
    def track!(args = nil)
      return unless @playground.collecting?
      timestamp, identity, values = track_args(args)
      connection.metric_track @id, timestamp, identity, values
      @playground.logger.info "vanity: #{@id} with value #{values.join(", ")}"
      call_hooks timestamp, identity, values
    end

    # Parses arguments to track! method and return array with timestamp,
    # identity and array of values.
    def track_args(args)
      case args
      when Hash
        timestamp, identity, values = args.values_at(:timestamp, :identity, :values)
      when Array
        values = args
      when Numeric
        values = [args]
      end
      identity ||= Vanity.context.vanity_identity rescue nil
      [timestamp || Time.now, identity, values || [1]]
    end
    protected :track_args

    # Metric definitions use this to introduce tracking hooks. The hook is
    # called with metric identifier, timestamp, count and possibly additional
    # arguments.
    #
    # For example:
    #   hook do |metric_id, timestamp, count|
    #     syslog.info metric_id
    #   end
    def hook(&block)
      @hooks << block
    end

    # This method returns the acceptable bounds of a metric as an array with
    # two values: low and high. Use nil for unbounded.
    #
    # Alerts are created when metric values exceed their bounds. For example,
    # a metric of user registration can use historical data to calculate
    # expected range of new registration for the next day. If actual metric
    # falls below the expected range, it could indicate registration process is
    # broken. Going above higher bound could trigger opening a Champagne
    # bottle.
    #
    # The default implementation returns +nil+.
    def bounds
    end


    #  -- Reporting --

    # Human readable metric name. All metrics must implement this method.
    attr_reader :name, :id
    alias :to_s :name

    # Human readable description. Use two newlines to break paragraphs.
    attr_writer :description

    # Sets or returns description. For example
    #   metric "Yawns/sec" do
    #     description "Most boring metric ever"
    #   end
    #
    #   puts "Just defined: " + metric(:boring).description
    def description(text = nil)
      @description = text if text
      @description if defined?(@description)
    end

    # Given two arguments, a start date and an end date (inclusive), returns an
    # array of measurements. All metrics must implement this method.
    def values(from, to)
      values = connection.metric_values(@id, from, to)
      values.map { |row| row.first.to_i }
    end

    # Returns date/time of the last update to this metric.
    #
    # @since 1.4.0
    def last_update_at
      connection.get_metric_last_update_at(@id)
    end


    # -- Storage --

    def destroy!
      connection.destroy_metric @id
    end

    def connection
      @playground.connection
    end

    def key(*args)
      "metrics:#{@id}:#{args.join(':')}"
    end

    def call_hooks(timestamp, identity, values)
      @hooks.each do |hook|
        hook.call @id, timestamp, values.first || 1, :identity=>identity
      end
    end

  end
end
