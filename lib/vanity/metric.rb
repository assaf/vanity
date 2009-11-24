module Vanity

  # A metric is an object with a method called values, which accepts two
  # arguments, start data and end date, and returns an array of measurements.
  #
  # A metric can also respons to additional methods (track!, bounds, etc).
  # This class implements a metric, use this as reference to the methods you
  # can implement in your own metric.
  #
  # Or just use this metric implementation.  It's fast and fully functional.
  # 
  # Startup metrics for pirates: AARRR stands for Acquisition, Activation,
  # Retention, Referral and Revenue.
  # http://500hats.typepad.com/500blogs/2007/09/startup-metrics.html
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
      
      # The playground this metric belongs to.
      attr_reader :playground

      # Defines a new metric, using the class Vanity::Metric.
      def metric(name, &block)
        metric = Metric.new(@playground, name.to_s.downcase.gsub(/\W/, "_"))
        metric.name = name
        metric.instance_eval &block
        metric
      end

    end

    class << self

      # Helper method to return name for a metric.
      #
      # A metric object may have a +name+ method that returns a short
      # descriptive name.  It may also have no name, or no +name+ method, in
      # which case the metric identifier will do.
      # 
      # Example:
      #   Vanity.playground.metrics.map { |id, metric| Vanity::Metric.name(id, metric) }
      def name(id, metric)
        metric.respond_to?(:name) && metric.name || id.to_s.capitalize.gsub(/_+/, " ")
      end

      # Helper method to return description for a metric.
      #
      # A metric object may have a +description+ method that returns a detailed
      # description.  It may also have no description, or no +description+
      # method, in which case return +nil+.
      # 
      # Example:
      #   puts Vanity::Metric.description(metric)
      def description(metric)
        metric.description if metric.respond_to?(:description)
      end

      # Helper method to return bounds for a metric.
      #
      # A metric object may have a +bounds+ method that returns lower and upper
      # bounds.  It may also have no bounds, or no +bounds+ # method, in which
      # case we return +[nil, nil]+.
      # 
      # Example:
      #   upper = Vanity::Metric.bounds(metric).last
      def bounds(metric)
        metric.respond_to?(:bounds) && metric.bounds || [nil, nil]
      end

      # Playground uses this to load metric definitions.
      def load(playground, stack, path, id)
        fn = File.join(path, "#{id}.rb")
        return Metric.new(playground, id) unless File.exist?(fn)

        fail "Circular dependency detected: #{stack.join('=>')}=>#{fn}" if stack.include?(fn)
        source = File.read(fn)
        begin
          stack.push fn
          context = Object.new
          context.instance_eval do
            extend Definition
            @playground = playground
            metric = eval source
            fail LoadError, "Expected #{fn} to define metric #{id}" unless metric.id == id
            metric
          end
        rescue
          error = LoadError.exception($!.message)
          error.set_backtrace $!.backtrace
          raise error
        ensure
          stack.pop
        end
      end

    end

    def initialize(playground, id)
      @playground = playground
      @id = id.to_sym
      @hooks = []
    end

    # Metric identifier.
    attr_reader :id


    # -- Tracking --

    # Called to track an action associated with this metric.
    def track!(vanity_id)
      timestamp = Time.now
      @playground.redis.incr "metrics:#{id}:#{timestamp.to_date}:count"
      @playground.logger.info "vanity tracked #{name || id}"
      @hooks.each do |hook|
        hook.call id, timestamp, vanity_id
      end
    end

    # Metric definitions use this to introduce tracking hook.  The hook is
    # called with three arguments: metric id, timestamp and vanity identity.
    #
    # For example:
    #   hook do |metric_id, timestamp, vanity_id|
    #     syslog.info metric_id
    #   end
    def hook(&block)
      @hooks << block
    end

    # This method returns the acceptable bounds of a metric as an array with
    # two values: low and high.  Use nil for unbounded.
    #
    # Alerts are created when metric values exceed their bounds.  For example,
    # a metric of user registration can use historical data to calculate
    # expected range of new registration for the next day.  If actual metric
    # falls below the expected range, it could indicate registration process is
    # broken.  Going above higher bound could trigger opening a Champagne
    # bottle.
    #
    # The default implementation returns +nil+.
    def bounds
    end
    

    #  -- Reporting --
    
    # Human readable metric name (first argument you pass when creating a new
    # metric).
    attr_accessor :name

    # Sets or returns description. For example
    #   metric "Yawns/sec" do
    #     description "Most boring metric ever"
    #   end
    #
    #   puts "Just defined: " + metric(:boring).description
    def description(text = nil)
      @description = text if text
      @description
    end

    # Sets or returns description. For example
    #   metric "Yawns/sec" do
    #     description "Most boring metric ever"
    #   end
    #
    #   puts "Just defined: " + metric(:boring).description
    def description(text = nil)
      @description = text if text
      @description
    end

    # All metrics implement this value.  Given two arguments, a start date and
    # an end date, it returns an array of measurements.
    def values(to, from)
      @playground.redis.mget((to.to_date..from.to_date).map { |date| "metrics:#{id}:#{date}:count" }).map(&:to_i)
    end

  end
end
