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
      @ar_timestamp, @ar_timestamp_table = @ar_timestamp.to_s.split('.').reverse
      @ar_timestamp_table ||= @ar_scoped.table_name
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
        begin
          time = Time.now.in_time_zone
          difference = time.to_date - Date.today
          sdate = sdate + difference
          edate = edate + difference
        rescue NoMethodError #In Rails 2.3, if no time zone has been set this fails
        end
        query = { :conditions=> { @ar_timestamp_table => { @ar_timestamp => (sdate.to_time...(edate + 1).to_time) } },
                  :group=>"date(#{@ar_scoped.quoted_table_name}.#{@ar_scoped.connection.quote_column_name @ar_timestamp})" }
        grouped = @ar_column ? @ar_scoped.send(@ar_aggregate, @ar_column, query) : @ar_scoped.count(query)
        grouped = Hash[grouped.map {|k,v| [k.to_date, v] }]
        (sdate..edate).inject([]) { |ordered, date| ordered << (grouped[date] || 0) }
      end

      # This track! method stores nothing, but calls the hooks.
      def track!(args = nil)
        return unless @playground.collecting?
        call_hooks *track_args(args)
      end

      def last_update_at
        record = @ar_scoped.find(:first, :order=>"#@ar_timestamp DESC", :limit=>1, :select=>@ar_timestamp)
        record && record.send(@ar_timestamp)
      end

      # AR model after_create callback notifies all the hooks.
      def after_create(record)
        return unless @playground.collecting?
        count = @ar_column ? (record.send(@ar_column) || 0) : 1
        call_hooks record.send(@ar_timestamp), nil, [count] if count > 0 && @ar_scoped.exists?(record)
      end
    end
  end
end
