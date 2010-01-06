module Vanity
  class Metric

    AGGREGATES = [:average, :minimum, :maximum, :sum]

    # Use an ActiveRecord model to get metric data from database table.  Also
    # forwards +after_create+ callbacks to hooks (updating experiments).
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
    # @see Vanity::Metric::ActiveRecord
    def model(class_or_scope, options = nil)
      options = options || {}
      conditions = options.delete(:conditions)
      @ar_scoped = conditions ? class_or_scope.scoped(:conditions=>conditions) : class_or_scope
      @ar_aggregate = AGGREGATES.find { |key| options.has_key?(key) }
      @ar_column = options.delete(@ar_aggregate)
      fail "Cannot use multiple aggregates in a single metric" if AGGREGATES.find { |key| options.has_key?(key) }
      @ar_timestamp = options.delete(:timestamp) || :created_at
      fail "Unrecognized options: #{options.keys * ", "}" unless options.empty?
      @ar_scoped.after_create self
      extend ActiveRecord
    end

    # Calling model method on a metric extends it with these modules, redefining
    # the values and track! methods.
    #
    # @since 1.3.0
    module ActiveRecord

      # This values method queries the database.
      def values(sdate, edate)
        query = { :conditions=>{ @ar_timestamp=>(sdate.to_time...(edate + 1).to_time) },
                  :group=>"date(#{@ar_scoped.connection.quote_column_name @ar_timestamp})" }
        grouped = @ar_column ? @ar_scoped.calculate(@ar_aggregate, @ar_column, query) : @ar_scoped.count(query)
        (sdate..edate).inject([]) { |ordered, date| ordered << (grouped[date.to_s] || 0) }
      end

      # This track! method stores nothing, but calls the hooks.
      def track!(*args)
        count = args.first || 1
        call_hooks Time.now, count if count > 0
      end

      # AR model after_create callback notifies all the hooks.
      def after_create(record)
        count = @ar_column ? (record.send(@ar_column) || 0) : 1
        call_hooks record.send(@ar_timestamp), count if count > 0 && @ar_scoped.exists?(record)
      end
    end
  end
end
