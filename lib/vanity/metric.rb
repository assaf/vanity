module Vanity

  # A metric is an object that implements two methods: +name+ and +values+.  It
  # can also respond to addition methods (+track!+, +bounds+, etc), these are
  # optional.
  #
  # This class implements a basic metric that tracks data and stores it in
  # Redis.  You can use this as the basis for your metric, or as reference for
  # the methods your metric must and can implement.
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
        metric.instance_eval &block
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
      # description.  It may also have no description, or no +description+
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
      # bounds.  It may also have no bounds, or no +bounds+ # method, in which
      # case we return +[nil, nil]+.
      # 
      # @example
      #   upper = Vanity::Metric.bounds(metric).last
      def bounds(metric)
        metric.respond_to?(:bounds) && metric.bounds || [nil, nil]
      end

      # Returns data set for a given date range.  The data set is an array of
      # date, value pairs.
      #
      # First argument is the metric.  Second argument is the start date, or
      # number of days to go back in history, defaults to 90 days.  Third
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
      redis.setnx key(:created_at), Time.now.to_i
      @created_at = Time.at(redis[key(:created_at)].to_i)
    end


    # -- Tracking --

    # Called to track an action associated with this metric.
    def track!(count = 1)
      count ||= 1
      if count > 0
        timestamp = Time.now
        redis.incrby key(timestamp.to_date, "count"), count
        @playground.logger.info "vanity: #{@id} with count #{count}"
        call_hooks timestamp, count
      end
    end

    # Metric definitions use this to introduce tracking hook.  The hook is
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
    
    # Human readable metric name.  All metrics must implement this method.
    attr_reader :name
    alias :to_s :name

    # Time stamp when metric was created.
    attr_reader :created_at

    # Human readable description.  Use two newlines to break paragraphs.
    attr_accessor :description

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

    # Given two arguments, a start date and an end date (inclusive), returns an
    # array of measurements.  All metrics must implement this method.
    def values(from, to)
      redis.mget((from.to_date..to.to_date).map { |date| key(date, "count") }).map(&:to_i)
    end


    # -- ActiveRecord support --

    AGGREGATES = [:average, :minimum, :maximum, :sum]

    # Use an ActiveRecord model to get metric data from database table.  Also
    # forwards @after_create@ callbacks to hooks (updating experiments).
    #
    # Supported options:
    # :conditions -- Only select records that match this condition
    # :average -- Metric value is average of this column
    # :minimum -- Metric value is minimum of this column
    # :maximum -- Metric value is maximum of this column
    # :sum -- Metric value is sum of this column
    # :timestamp -- Use this column to filter/group records (defaults to
    # +created_at+)
    #
    # @example Track sign ups using User model
    #   metric "Signups" do
    #     model Account
    #   end
    # @example Track satisfaction using Survey model
    #   metric "Satisfaction" do
    #     model Survey, :average=>:rating
    #   end
    # @example Track only high ratings
    #   metric "High ratings" do
    #     model Rating, :conditions=>["stars >= 4"]
    #   end
    # @example Track only high ratings (using scope)
    #   metric "High ratings" do
    #     model Rating.high
    #   end
    #
    # @since 1.2.0
    def model(class_or_scope, options = nil)
      options = (options || {}).clone
      conditions = options.delete(:conditions)
      scoped = conditions ? class_or_scope.scoped(:conditions=>conditions) : class_or_scope
      aggregate = AGGREGATES.find { |key| options.has_key?(key) }
      column = options.delete(aggregate)
      fail "Cannot use multiple aggregates in a single metric" if AGGREGATES.find { |key| options.has_key?(key) }
      timestamp = options.delete(:timestamp) || :created_at
      fail "Unrecognized options: #{options.keys * ", "}" unless options.empty?

      # Hook into model's after_create
      scoped.after_create do |record|
        count = column ? (record.send(column) || 0) : 1
        call_hooks record.send(timestamp), count if count > 0 && scoped.exists?(record)
      end
      # Redefine values method to perform query
      eigenclass = class << self ; self ; end
      eigenclass.send :define_method, :values do |sdate, edate|
        query = { :conditions=>{ timestamp=>(sdate.to_time...(edate + 1).to_time) }, :group=>"date(#{scoped.connection.quote_column_name timestamp})" }
        grouped = column ? scoped.calculate(aggregate, column, query) : scoped.count(query)
        (sdate..edate).inject([]) { |ordered, date| ordered << (grouped[date.to_s] || 0) }
      end
      # Redefine track! method to call on hooks
      eigenclass.send :define_method, :track! do |*args|
        count = args.first || 1
        call_hooks Time.now, count if count > 0
      end
    end


    # -- Google Analytics support --

    # Use Google Analytics metric.
    # 
    # @example Page views
    #   metric "Page views" do
    #     google_analytics "UA-1828623-6"
    #   end
    # @example Visits
    #   metric "Visits" do
    #     google_analytics "UA-1828623-6", :visits
    #   end
    def google_analytics(web_property_id, metric = :pageviews, filter = nil)
      gem "garb"
      require "garb"
      profile = Garb::Profile.all.find { |p| p.web_property_id == web_property_id }
      eigenclass = class << self ; self ; end
      eigenclass.send :define_method, :values do |from, to|
        report = Garb::Report.new(profile, { :start_date => from, :end_date => to })
        report.metrics metric
        report.dimensions :date
        report.sort :date
        #report.filter filter
        # hack because GA data isn't returned if it's 0
        data = report.results.inject({}) do |hash, result|
          hash.merge(result.date => result.send(metric).to_i)
        end
        (from..to).map { |day| data[day.strftime('%Y%m%d')] || 0 }
      end
    rescue Gem::LoadError
      fail LoadError, "Google Analytics metrics require Garb, please gem install garb first"
    end

  
    # -- Storage --

    def destroy!
      redis.del redis.keys(key("*"))
    end

    def redis
      @playground.redis
    end

    def key(*args)
      "metrics:#{@id}:#{args.join(':')}"
    end

    def call_hooks(timestamp, count)
      count ||= 1
      @hooks.each do |hook|
        hook.call @id, timestamp, count
      end
    end

  end
end
