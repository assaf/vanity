module Vanity
  module Rails #:nodoc:
    def self.load!
      Vanity.playground.load_path = ::Rails.root + Vanity.playground.load_path
      Vanity.playground.logger ||= ::Rails.logger

      # Do this at the very end of initialization, allowing you to change
      # connection adapter, turn collection on/off, etc.
      ::Rails.configuration.after_initialize do
        Vanity.playground.load!
      end
    end

    # The use_vanity method will setup the controller to allow testing and
    # tracking of the current user.
    module UseVanity
      # Defines the vanity_identity method and the set_identity_context filter.
      #
      # Call with the name of a method that returns an object whose identity
      # will be used as the Vanity identity.  Confusing?  Let's try by example:
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
      # set the identity for you (using a cookie to remember it across
      # requests).  It also uses this mechanism if you don't provide an
      # identity object, by calling use_vanity with no arguments.
      #
      # Of course you can also use a block:
      #   class ProjectController < ApplicationController
      #     use_vanity { |controller| controller.params[:project_id] }
      #   end
      def use_vanity(symbol = nil, &block)
        if block
          define_method(:vanity_identity) { block.call(self) }
        else
          define_method :vanity_identity do
            return @vanity_identity if @vanity_identity
            if symbol && object = send(symbol)
              @vanity_identity = object.id
            elsif response # everyday use
              @vanity_identity = cookies["vanity_id"] || ActiveSupport::SecureRandom.hex(16)
              cookie_options = { :value=>@vanity_identity, :expires=>1.month.from_now }
              if ::Rails.respond_to?(:application)
                cookie_options[:domain] = ::Rails.application.config.session_options[:domain] if ::Rails.application.config.session_options[:domain]
              end
              cookies["vanity_id"] = cookie_options
              @vanity_identity
            else # during functional testing
              @vanity_identity = "test"
            end
          end
        end
        around_filter :vanity_context_filter
        before_filter :vanity_reload_filter unless ::Rails.configuration.cache_classes
        before_filter :vanity_query_parameter_filter
      end
      protected :use_vanity
    end


    # Vanity needs these filters.  They are includes in ActionController and
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
      # see them all).  A request with the _vanity query parameter is
      # intercepted, the alternative is chosen, and the user redirected to the
      # same request URL sans _vanity parameter.  This only works for GET
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

      # Before filter to reload Vanity experiments/metrics.  Enabled when
      # cache_classes is false (typically, testing environment).
      def vanity_reload_filter
        Vanity.playground.reload!
      end

      protected :vanity_context_filter, :vanity_query_parameter_filter, :vanity_reload_filter
    end


    # Introduces ab_test helper (controllers and views).  Similar to the generic
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
        if Vanity.playground.using_js?
          @_vanity_experiments ||= {}
          @_vanity_experiments[name] ||= Vanity.playground.experiment(name).choose
          value = @_vanity_experiments[name].value
        else
          value = Vanity.playground.experiment(name).choose.value
        end
 
        if block
          content = capture(value, &block)
          block_called_from_erb?(block) ? concat(content) : content
        else
          value
        end
      end

      def vanity_js
        return if @_vanity_experiments.nil?
        javascript_tag do
          render Vanity.template("vanity.js.erb")
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
        render :file=>Vanity.template("_report"), :content_type=>Mime::HTML, :layout=>false
      end

      def chooses
        exp = Vanity.playground.experiment(params[:e])
        exp.chooses(exp.alternatives[params[:a].to_i].value)
        render :file=>Vanity.template("_experiment"), :locals=>{:experiment=>exp}
      end

      def add_participant
	if params[:e].nil? || params[:e].empty?
	  render :status => 404, :nothing => true
	  return
	end
        exp = Vanity.playground.experiment(params[:e])
        exp.chooses(exp.alternatives[params[:a].to_i].value)
        render :status => 200, :nothing => true
      end
    end
  end
end


# Enhance ActionController with use_vanity, filters and helper methods.
if defined?(ActionController)
  # Include in controller, add view helper methods.
  ActionController::Base.class_eval do
    extend Vanity::Rails::UseVanity
    include Vanity::Rails::Filters
    helper Vanity::Rails::Helpers
  end

  module ActionController
    class TestCase
      alias :setup_controller_request_and_response_without_vanity :setup_controller_request_and_response
      # Sets Vanity.context to the current controller, so you can do things like:
      #   experiment(:simple).chooses(:green)
      def setup_controller_request_and_response
        setup_controller_request_and_response_without_vanity
        Vanity.context = @controller
      end
    end
  end
end


# Automatically configure Vanity.
if defined?(Rails)
  if Rails.const_defined?(:Railtie) # Rails 3
    class Plugin < Rails::Railtie # :nodoc:
      initializer "vanity.require" do |app|
        Vanity::Rails.load!
      end
    end
  else
    Rails.configuration.after_initialize do
      Vanity::Rails.load!
    end
  end
end


# Reconnect whenever we fork under Passenger.
if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      begin
        Vanity.playground.establish_connection if Vanity.playground.collecting?
      rescue Exception=>ex
        Rails.logger.error "Error reconnecting: #{ex.to_s}"
      end
    end
  end
end
