module Vanity
  class Metric
    
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
    #
    # @since 1.3.0
    # @see Vanity::Metric::GoogleAnalytics
    def google_analytics(web_property_id, *args)
      gem "garb"
      require "garb"
      options = Hash === args.last ? args.pop : {}
      metric = options.shift || :pageviews
      @ga_resource = Vanity::Metric::GoogleAnalytics::Resource.new(web_property_id, metric)
      @ga_mapper = options[:mapper] ||= lambda { |entry| entry.send(@ga_resource.metrics.elements.first).to_i }
      extend GoogleAnalytics
    rescue Gem::LoadError
      fail LoadError, "Google Analytics metrics require Garb, please gem install garb first"
    end

    # Calling google_analytics method on a metric extends it with these modules,
    # redefining the values and hook methods.
    #
    # @since 1.3.0
    module GoogleAnalytics

      # Returns values from GA using parameters specified by prior call to
      # google_analytics.
      def values(from, to)
        data = @ga_resource.results(from, to).inject({}) do |hash,entry|
          hash.merge(entry.date=>@ga_mapper.call(entry))
        end
        (from..to).map { |day| data[day.strftime('%Y%m%d')] || 0 }
      end
      
      # Hooks not supported for GA metrics.
      def hook
        fail "Cannot use hooks with Google Analytics methods"
      end

      class Resource
        include Garb::Resource

        def initialize(web_property_id, metric)
          @web_property_id = web_property_id
          metrics metric
          dimensions :date
          sort :date
        end

        def results(start_date, end_date)
          @profile = Garb::Profile.all.find { |p| p.web_property_id == @web_property_id }
          @start_date = start_date
          @end_date = end_date
          Garb::ReportResponse.new(send_request_for_body).results
        end

      end

    end
  end
end
