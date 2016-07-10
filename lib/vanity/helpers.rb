module Vanity
  # Helper methods available on Object.
  #
  # @example From ERB template
  #   <%= ab_test(:greeting) %> <%= current_user.name %>
  # @example From Rails controller
  #   class AccountController < ApplicationController
  #     def create
  #       Vanity.track!(:signup)
  #       Acccount.create!(params[:account])
  #     end
  #   end
  # @example From ActiveRecord
  #   class Posts < ActiveRecord::Base
  #     after_create do |post|
  #       Vanity.track!(:images if post.type == :image)
  #     end
  #   end
  module Helpers

    # This method returns one of the alternative values in the named A/B test.
    #
    # @example A/B two alternatives for a page
    #   def index
    #     if Vanity.ab_test(:new_page) # true/false test
    #       render action: "new_page"
    #     else
    #       render action: "index"
    #     end
    #   end
    # @example Similar, alternative value is page name
    #   def index
    #     render action: Vanity.ab_test(:new_page)
    #   end
    # @since 1.2.0
    def ab_test(name, &block)
      # TODO refactor with Vanity::Rails::Helpers#ab_test, however that's used
      # within Rails views
      request = respond_to?(:request) ? self.request : nil
      if Vanity.playground.using_js?
        value = Vanity.context.vanity_store_experiment_for_js name, Vanity.playground.experiment(name).choose(request)
      else
        value = Vanity.playground.experiment(name).choose(request).value
      end

      if block
        capture(value, &block)
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
    #   Vanity.track!(:invitation)
    # @example
    #   Vanity.track!(:click, { :identity=>Identity.new(env['rack.session']), :values=>[1] })
    #
    # @param count_or_options Defaults to a count of 1. Also accepts a hash
    #   of options passed (eventually) to AbTest#track!.
    # @since 1.2.0
    def track!(name, count_or_options = 1)
      Vanity.playground.track! name, count_or_options
    end
  end
end
