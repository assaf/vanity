module Vanity
  # Helper methods for use in your controllers.
  #
  # 1) Use Vanity from within your controller:
  #
  #   class ApplicationController < ActionController::Base include
  #   Vanity::Helpers use_vanity :current_user end
  #
  # 2) Present different options for an A/B test:
  #
  #   Get started for only $<%= ab_test :pricing %> a month!
  #
  # 3) Measure conversion:
  #
  #   def signup ab_goal! :pricing . . .  end
  module Helpers
    module ClassMethods

      # Defines the vanity_identity method, and the set_identity_context before
      # filter.
      #
      # First argument names a method that returns an object whose identity is
      # the vanity identity.  Identity is used to present an experiment
      # consistently to the same person or people.  It can be the user's
      # identity, group, project.  The object must provide its identity in
      # response to the method +id+.
      #
      # For example, if +current_user+ returns a +User+ object, then to use the
      # user's id:
      #   class ApplicationController < ActionController::Base
      #     include Vanity::Helpers
      #     use_vanity :current_user
      #   end
      #
      # If that method returns nil (e.g. the user has not signed in), a random
      # value will be used, instead.  That random value is maintained using a
      # cookie.
      #
      # If there is no identity you can use, call use_vanity with the value +nil+.
      #
      # For example:
      #   class ApplicationController < ActionController::Base
      #     include Vanity::Helpers
      #     use_vanity :current_user
      #   end
      def use_vanity(symbol)
        define_method :vanity_identity do
          return @vanity_identity if @vanity_identity
          if symbol && object = send(symbol)
            @vanity_identity = object.id
          else
            @vanity_identity = cookies["vanity_id"] || OpenSSL::Random.random_bytes(16).unpack("H*")[0]
            cookies["vanity_id"] = { value: @vanity_identity, expires: 1.month.from_now }
            @vanity_identity
          end
        end
        define_method :set_vanity_context do
          Vanity.context = self
        end
        before_filter :set_vanity_context

        helper Vanity::Helpers
      end
    end

    def self.included(base) #:nodoc:
      base.extend ClassMethods
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
    #     ab_goal! :call_to_action
    #     Acccount.create! params[:account]
    #   end
    def ab_goal!(name)
      Vanity.playground.experiment(name).conversion!
    end
  end
end
