require "vanity/rails/helpers"
require "vanity/rails/testing"
require "vanity/rails/dashboard"

# Use Rails logger by default.
Vanity.playground.logger ||= ActionController::Base.logger
Vanity.playground.load_path = "#{RAILS_ROOT}/experiments"

# Include in controller, add view helper methods.
ActionController::Base.class_eval do
  extend Vanity::Rails::ClassMethods
  include Vanity::Rails
  helper Vanity::Rails
end
