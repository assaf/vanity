module Vanity  
  # Helper methods for use in your controllers.
  #
  # 1) Use Vanity from within your controller:
  #
  #   class ApplicationController < ActionController::Base
  #     use_vanity :current_user end
  #   end
  #
  # 2) Present different options for an A/B test:
  #
  #   Get started for only $<%= ab_test :pricing %> a month!
  #
  # 3) Measure conversion:
  #
  #   def signup
  #     track! :pricing
  #     . . .
  #   end
  module Rails
    module UseVanity

    protected

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
              cookies["vanity_id"] = { :value=>@vanity_identity, :expires=>1.month.from_now }
              @vanity_identity
            else # during functional testing
              @vanity_identity = "test"
            end
          end
        end
        around_filter :vanity_context_filter
        before_filter :vanity_reload_filter unless ::Rails.configuration.cache_classes
      end

    end

    module Filters
    protected

      # Around filter that sets Vanity.context to controller.
      def vanity_context_filter
        previous, Vanity.context = Vanity.context, self
        yield
      ensure
        Vanity.context = previous
      end

      # Before filter to reload Vanity experiments/metrics.  Enabled when
      # cache_classes is false (typically, testing environment).
      def vanity_reload_filter
        Vanity.playground.reload!
      end

    end

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
      value = Vanity.playground.experiment(name).choose
      if block
        content = capture(value, &block)
        block_called_from_erb?(block) ? concat(content) : content
      else
        value
      end
    end

    end

  end
end
