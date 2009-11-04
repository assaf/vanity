module Vanity
  # Helper methods for use in your controllers.
  #
  # 1. Use vanity from within your controller:
  #
  #   class ApplicationController < ActionController::Base
  #     include Vanity::Helpers
  #     use_vanity :current_user
  #   end
  #
  # 2. Present different options for an A/B test:
  #
  #   Get started for only $<%= ab_test :pricing %> a month!
  #
  # 3. Measure conversion:
  #
  #   def signup
  #     ab_goal! :pricing
  #     . . .
  #   end
  module Helpers
    module ClassMethods
      # Define set_vanity_identity method and use it as before filter. First argument
      # is the name of a method that returns the current user, second argument are options
      # passed to before_filter.
      #
      # For example:
      #   class ApplicationController < ActionController::Base
      #     include Vanity::Helpers
      #     use_vanity :current_user
      #   end
      #
      #   class SomeController < ApplicationController
      #     use_vanity :current_user, except: :feed
      #     . . .
      #   end
      def use_vanity(symbol, options = nil)
        define_method :set_vanity_identity do
          if symbol && user = send(symbol)
            Vanity.identity = user.id
          else
            Vanity.identity = cookies['vanity_id']
            cookies['vanity_id'] = { value: Vanity.identity, expires: 1.month.from_now }
          end
        end
        before_filter :set_vanity_identity
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
      choice = Vanity.playground.experiment(name).choice(Vanity.identity)
      if block
        content = capture(choice, &block)
        block_called_from_erb?(block) ? concat(content) : content
      else
        choice
      end
    end

    # This method records conversion on the named A/B test. For example:
    #   def create
    #     ab_goal! :call_to_action
    #     Acccount.create! params[:account]
    #   end
    def ab_goal!(name)
      Vanity.playground.experiment(name).converted(Vanity.identity)
    end
  end
end
