module Vanity
  module Rails
    def self.load!
      ::Rails.configuration.before_initialize do
        Vanity.configuration.logger ||= ::Rails.logger
        Vanity.configuration.setup_locales
      end

      # Do this at the very end of initialization, allowing you to change
      # connection adapter, turn collection on/off, etc.
      ::Rails.configuration.after_initialize do
        Vanity.load! if Vanity.connection.connected?
      end
    end

    # The use_vanity method will setup the controller to allow testing and
    # tracking of the current user.
    module UseVanity
      # Defines the vanity_identity method and the set_identity_context filter.
      #
      # Call with the name of a method that returns an object whose identity
      # will be used as the Vanity identity if the user is not already
      # cookied. Confusing?  Let's try by example:
      #
      #   class ApplicationController < ActionController::Base
      #     use_vanity :current_user
      #
      #     def current_user
      #       User.find(session[:user_id])
      #     end
      #   end
      #
      # If that method (current_user in this example) returns nil, Vanity will
      # look for a vanity cookie. If there is none, it will create an identity
      # (using a cookie to remember it across requests). It also uses this
      # mechanism if you don't provide an identity object, by calling
      # use_vanity with no arguments.
      #
      # You can also use a block:
      #   class ProjectController < ApplicationController
      #     use_vanity { |controller| controller.params[:project_id] }
      #   end
      def use_vanity(symbol = nil, &block)
        define_method :vanity_store_experiment_for_js do |name, alternative|
          @_vanity_experiments ||= {}
          @_vanity_experiments[name] ||= alternative
          @_vanity_experiments[name].value
        end

        if block
          define_method(:vanity_identity) { block.call(self) }
        else
          define_method :vanity_identity do
            return @vanity_identity if @vanity_identity

            # With user sign in, it's possible to visit not-logged in, get
            # cookied and shown alternative A, then sign in and based on
            # user.id, get shown alternative B.
            # This implementation prefers an initial vanity cookie id over a
            # new user.id to avoid the flash of alternative B (FOAB).
            if request.get? && params[:_identity]
              @vanity_identity = params[:_identity]
              cookies["vanity_id"] = { :value=>@vanity_identity, :expires=>1.month.from_now }
              @vanity_identity
            elsif cookies["vanity_id"]
              @vanity_identity = cookies["vanity_id"]
            elsif symbol && object = send(symbol)
              @vanity_identity = object.id
            elsif response # everyday use
              @vanity_identity = cookies["vanity_id"] || SecureRandom.hex(16)
              cookie = { :value=>@vanity_identity, :expires=>1.month.from_now }
              # Useful if application and admin console are on separate domains.
              cookie[:domain] ||= ::Rails.application.config.session_options[:domain]
              cookies["vanity_id"] = cookie
              @vanity_identity
            else # during functional testing
              @vanity_identity = "test"
            end
          end
        end
        protected :vanity_identity
        around_filter :vanity_context_filter
        before_filter :vanity_reload_filter unless ::Rails.configuration.cache_classes
        before_filter :vanity_query_parameter_filter
        after_filter :vanity_track_filter
      end
      protected :use_vanity
    end

    module UseVanityMailer
      def use_vanity_mailer(symbol = nil)
        # Context is the instance of ActionMailer::Base
        Vanity.context = self
        if symbol && (@object = symbol)
          class << self
            define_method :vanity_identity do
              @vanity_identity = (String === @object ? @object : @object.id)
            end
          end
        else
          class << self
            define_method :vanity_identity do
              @vanity_identity = @vanity_identity || SecureRandom.hex(16)
            end
          end
        end
      end
      protected :use_vanity_mailer
    end

    # Vanity needs these filters. They are includes in ActionController and
    # automatically added when you use #use_vanity in your controller.
    module Filters
      # Around filter that sets Vanity.context to controller.
      def vanity_context_filter
        previous, Vanity.context = Vanity.context, self
        yield
      ensure
        Vanity.context = previous
      end

      # This filter allows user to choose alternative in experiment using query
      # parameter.
      #
      # Each alternative has a unique fingerprint (run vanity list command to
      # see them all). A request with the _vanity query parameter is
      # intercepted, the alternative is chosen, and the user redirected to the
      # same request URL sans _vanity parameter. This only works for GET
      # requests.
      #
      # For example, if the user requests the page
      # http://example.com/?_vanity=2907dac4de, the first alternative of the
      # :null_abc experiment is chosen and the user redirected to
      # http://example.com/.
      def vanity_query_parameter_filter
        if request.get? && params[:_vanity]
          hashes = Array(params.delete(:_vanity))
          Vanity.playground.experiments.each do |id, experiment|
            if experiment.respond_to?(:alternatives)
              experiment.alternatives.each do |alt|
                if hash = hashes.delete(experiment.fingerprint(alt))
                  experiment.chooses alt.value
                  break
                end
              end
            end
            break if hashes.empty?
          end
          redirect_to url_for(params)
        end
      end

      # Before filter to reload Vanity experiments/metrics. Enabled when
      # cache_classes is false (typically, testing environment).
      def vanity_reload_filter
        Vanity.playground.reload!
      end

      # Filter to track metrics. Pass _track param along to call track! on that
      # alternative.
      def vanity_track_filter
        if request.get? && params[:_track]
          track! params[:_track]
        end
      end

      protected :vanity_context_filter, :vanity_query_parameter_filter, :vanity_reload_filter
    end


    # Introduces ab_test helper (controllers and views). Similar to the generic
    # ab_test method, with the ability to capture content (applicable to views,
    # see examples).
    module Helpers
      # This method returns one of the alternative values in the named A/B test.
      #
      # @example A/B two alternatives for a page
      #   def index
      #     if ab_test(:new_page) # true/false test
      #       render action: "new_page"
      #     else
      #       render action: "index"
      #     end
      #   end
      # @example Similar, alternative value is page name
      #   def index
      #     render action: ab_test(:new_page)
      #   end
      # @example A/B test inside ERB template (condition)
      #   <%= if ab_test(:banner) %>100% less complexity!<% end %>
      # @example A/B test inside ERB template (value)
      #   <%= ab_test(:greeting) %> <%= current_user.name %>
      # @example A/B test inside ERB template (capture)
      #   <% ab_test :features do |count| %>
      #     <%= count %> features to choose from!
      #   <% end %>
      def ab_test(name, &block)
        value = setup_experiment(name)

        if block
          content = capture(value, &block)
          if defined?(block_called_from_erb?) && block_called_from_erb?(block)
             concat(content)
          else
            content
          end
        else
          value
        end
      end

      # Generate url with the identity of the current user and the metric to track on click
      def vanity_track_url_for(identity, metric, options = {})
        options = options.merge(:_identity => identity, :_track => metric)
        url_for(options)
      end

      # Generate url with the fingerprint for the current Vanity experiment
      def vanity_tracking_image(identity, metric, options = {})
        options = options.merge(:controller => :vanity, :action => :image, :_identity => identity, :_track => metric)
        image_tag(url_for(options), :width => "1px", :height => "1px", :alt => "")
      end

      def vanity_js
        return if @_vanity_experiments.nil? || @_vanity_experiments.empty?
        javascript_tag do
          render :file => Vanity.template("_vanity"), :formats => [:js]
        end
      end

      def vanity_h(text)
        h(text)
      end

      def vanity_html_safe(text)
        if text.respond_to?(:html_safe)
          text.html_safe
        else
          text
        end
      end

      def vanity_simple_format(text, html_options={})
        vanity_html_safe(simple_format(text, html_options))
      end

      # Return a copy of the active experiments on a page
      #
      # @example Render some info about each active experiment in development mode
      #   <% if Rails.env.development? %>
      #     <% vanity_experiments.each do |name, alternative| %>
      #       <span>Participating in <%= name %>, seeing <%= alternative %>:<%= alternative.value %> </span>
      #     <% end %>
      #   <% end %>
      # @example Push experiment values into javascript for use there
      #   <% experiments = vanity_experiments %>
      #   <% unless experiments.empty? %>
      #     <script>
      #       <% experiments.each do |name, alternative| %>
      #         myAbTests.<%= name.to_s.camelize(:lower) %> = '<%= alternative.value %>';
      #       <% end %>
      #     </script>
      #   <% end %>
      def vanity_experiments
        @_vanity_experiments ||= {}
        experiments = {}

        @_vanity_experiments.each do |name, alternative|
          experiments[name] = alternative.clone
        end

        experiments
      end

      protected

      def setup_experiment(name)
        @_vanity_experiments ||= {}
        request = respond_to?(:request) ? self.request : nil
        @_vanity_experiments[name] ||= Vanity.playground.experiment(name.to_sym).choose(request)
        @_vanity_experiments[name].value
      end

    end


    # Step 1: Add a new resource in config/routes.rb:
    #   map.vanity "/vanity/:action/:id", :controller=>:vanity
    #
    # Step 2: Create a new experiments controller:
    #   class VanityController < ApplicationController
    #     include Vanity::Rails::Dashboard
    #   end
    #
    # Step 3: Open your browser to http://localhost:3000/vanity
    module Dashboard
      def index
        render :file=>Vanity.template("_report"),:content_type=>Mime::HTML, :locals=>{
          :experiments=>Vanity.playground.experiments,
          :experiments_persisted=>Vanity.playground.experiments_persisted?,
          :metrics=>Vanity.playground.metrics
        }
      end

      def participant
        render :file=>Vanity.template("_participant"), :locals=>{:participant_id => params[:id], :participant_info => Vanity.playground.participant_info(params[:id])}, :content_type=>Mime::HTML
      end

      def complete
        exp = Vanity.playground.experiment(params[:e].to_sym)
        alt = exp.alternatives[params[:a].to_i]
        confirmed = params[:confirmed]
        # make the user confirm before completing an experiment
        if confirmed && confirmed.to_i==alt.id && exp.active?
          exp.complete!(alt.id)
          render :file=>Vanity.template("_experiment"), :locals=>{:experiment=>exp}
        else
          @to_confirm = alt.id
          render :file=>Vanity.template("_experiment"), :locals=>{:experiment=>exp}
        end
      end

      def chooses
        exp = Vanity.playground.experiment(params[:e].to_sym)
        exp.chooses(exp.alternatives[params[:a].to_i].value)
        render :file=>Vanity.template("_experiment"), :locals=>{:experiment=>exp}
      end

      def reset
        exp = Vanity.playground.experiment(params[:e].to_sym)
        exp.reset
        flash[:notice] = I18n.t 'vanity.experiment_has_been_reset', name: exp.name
        render :file=>Vanity.template("_experiment"), :locals=>{:experiment=>exp}
      end

      # JS callback action used by vanity_js
      def add_participant
        if params[:v].nil?
          render :status => 404, :nothing => true
          return
        end

        h = {}
        params[:v].split(',').each do |pair|
          exp_id, answer = pair.split('=')
          exp = Vanity.playground.experiment(exp_id.to_s.to_sym) rescue nil
          answer = answer.to_i

          if !exp || !exp.alternatives[answer]
            render :status => 404, :nothing => true
            return
          end
          h[exp] = exp.alternatives[answer].value
        end

        h.each{ |e,a| e.chooses(a, request) }
        render :status => 200, :nothing => true
      end
    end

    module TrackingImage
      def image
        # send image
        send_file(File.expand_path("../images/x.gif", File.dirname(__FILE__)), :type => 'image/gif', :stream => false, :disposition => 'inline')
      end
    end
  end
end


# Enhance ActionController with use_vanity, filters and helper methods.
ActiveSupport.on_load(:action_controller) do
  # Include in controller, add view helper methods.
  ActionController::Base.class_eval do
    extend Vanity::Rails::UseVanity
    include Vanity::Rails::Filters
    helper Vanity::Rails::Helpers
  end
end


# Include in mailer, add view helper methods.
ActiveSupport.on_load(:action_mailer) do
  include Vanity::Rails::UseVanityMailer
  include Vanity::Rails::Filters
  helper Vanity::Rails::Helpers
end

# Reconnect whenever we fork under Passenger.
if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      begin
        Vanity.playground.reconnect! if Vanity.playground.collecting?
      rescue Exception=>ex
        Rails.logger.error "Error reconnecting: #{ex.to_s}"
      end
    end
  end
end
