module Vanity  
  # Helper methods available on Object.
  #
  # @example From ERB template
  #   <%= ab_test(:greeting) %> <%= current_user.name %>
  # @example From Rails controller
  #   class AccountController < ApplicationController
  #     def create
  #       track! :signup
  #       Acccount.create! params[:account]
  #     end
  #   end
  # @example From ActiveRecord
  #   class Posts < ActiveRecord::Base
  #     after_create do |post|
  #       track! :images if post.type == :image
  #     end
  #   end
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
    # @since 1.2.0
    def ab_test(name, &block)
      value = Vanity.playground.experiment(name).choose
      if block
        content = capture(value, &block)
        block_called_from_erb?(block) ? concat(content) : content
      else
        value
      end
    end

    # Tracks an action associated with a metric.
    #
    # @example
    #   track! :invitation
    # @since 1.2.0
    def track!(name, count = 1)
      Vanity.playground.track! name, count
    end
  end
end

Object.class_eval do
  include Vanity::Helpers
end
