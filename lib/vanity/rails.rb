require "vanity/rails/helpers"
require "vanity/rails/testing"
require "vanity/rails/dashboard"

# Include in controller, add view helper methods.
ActionController::Base.class_eval do
  extend Vanity::Rails::UseVanity
  include Vanity::Rails::Filters
  helper Vanity::Rails::Helpers
end

Rails.configuration.after_initialize do
  # Use Rails logger by default.
  Vanity.playground.logger ||= ActionController::Base.logger
  Vanity.playground.load_path = "#{RAILS_ROOT}/experiments"

  # Do this at the very end of initialization, allowing test environment to do
  # Vanity.playground.mock! before any database access takes place.
  Rails.configuration.after_initialize do
    Vanity.playground.load!
  end
end

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked| 
    if forked 
      begin
        Vanity.playground.reconnect!
      rescue Exception=>ex
        RAILS_DEFAULT_LOGGER.error "Error reconnecting Redis: #{ex.to_s}" 
      end
    end 
  end 
end
