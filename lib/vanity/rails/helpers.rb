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
    module ClassMethods

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
        define_method :vanity_identity do
          return @vanity_identity if @vanity_identity
          if block
            @vanity_identity = block.call(self)
          elsif symbol && object = send(symbol)
            @vanity_identity = object.id
          elsif response # everyday use
            @vanity_identity = cookies["vanity_id"] || OpenSSL::Random.random_bytes(16).unpack("H*")[0]
            cookies["vanity_id"] = { :value=>@vanity_identity, :expires=>1.month.from_now }
            @vanity_identity
          else # during functional testing
            @vanity_identity = "test"
          end
        end
        define_method :set_vanity_context do
          Vanity.context = self
        end
        before_filter :set_vanity_context
        before_filter { Vanity.playground.reload! } unless ::Rails.configuration.cache_classes
      end
    end

    # This method returns one of the alternative values in the named A/B test.
    #
    # Examples using ab_test inside controller:
    #   def index
    #     if ab_test(:new_page) # true/false test
    #       render action: "new_page"
    #     else
    #       render action: "index"
    #     end
    #   end
    #
    #   def index
    #     render action: ab_test(:new_page) # alternatives are page names
    #   end
    # 
    # Examples using ab_test inside view:
    #   <%= if ab_test(:banner) %>100% less complexity!<% end %>
    #
    #   <%= ab_test(:greeting) %> <%= current_user.name %>
    #
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

    # This method records conversion on the named A/B test. For example:
    #   def create
    #     track! :call_to_action
    #     Acccount.create! params[:account]
    #   end
    def track!(name)
      Vanity.playground.track! name
    end
  end
end
