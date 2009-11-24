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

    class << self

      # Helper method to return title for a metric.
      #
      # A metric object may have a +title+ method that returns a short
      # descriptive title.  It may also have no title, or no +title+ method, in
      # which case the metric identifier will do.
      # 
      # Example:
      #   Vanity.playground.metrics.map { |id, metric| Vanity::Metric.title(id, metric) }
      def title(id, metric)
        metric.respond_to?(:title) && metric.title || id.to_s.capitalize.gsub(/_+/, " ")
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

    end

    def initialize(playground, id)
      @playground = playground
      @id = id
      @hooks = []
    end

    # All metrics implement this value.  Given two arguments, a start date and
    # an end date, it returns an array of measurements.
    def values(to, from)
      @playground.redis.mget((to.to_date..from.to_date).map { |date| "metrics:#{id}:#{date}:count" }).map(&:to_i)
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

    # Metric identifier.
    attr_accessor :id

    # Metric title.
    attr_accessor :title

    # Metric description.
    attr_accessor :description

    # Called to track an action associated with this metric.
    def track!(vanity_id)
      timestamp = Time.now
      @playground.redis.incr "metrics:#{id}:#{timestamp.to_date}:count"
      @playground.logger.info "vanity tracked #{title || id}"
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
  end
end
