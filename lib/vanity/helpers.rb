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
      # TODO refactor with Vanity::Rails::Helpers#ab_test
      request = respond_to?(:request) ? self.request : nil
      if Vanity.playground.using_js?
        value = Vanity.context.vanity_store_experiment_for_js name, Vanity.playground.experiment(name).choose(request)
      else
        value = Vanity.playground.experiment(name).choose(request).value
      end

      if block
        content = capture(value, &block)
        block_called_from_erb?(block) ? concat(content) : content
      else
        value
      end
    end

    # Tracks an action associated with a metric. Useful for calling from a
    # Rack handler. Note that a user should already be added to an experiment
    # via #ab_test before this is called - otherwise, the conversion will be
    # tracked, but the user will not be added to the experiment.
    #
    # @example
    #   track! :invitation
    # @example
    #   track! :click, { :identity=>Identity.new(env['rack.session']), :values=>[1] }
    #
    # @param count_or_options Defaults to a count of 1. Also accepts a hash
    #   of options passed (eventually) to AbTest#track!.
    # @since 1.2.0
    def track!(name, count_or_options = 1)
      Vanity.playground.track! name, count_or_options
    end
  end
end

# TODO do we actually want to do this?
Object.class_eval do
  include Vanity::Helpers
end
