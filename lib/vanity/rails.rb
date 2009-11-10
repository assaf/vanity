require File.join(File.dirname(__FILE__), "../vanity")
require File.join(File.dirname(__FILE__), "rails/helpers")
require File.join(File.dirname(__FILE__), "rails/testing")

# Use Rails logger by default.
Vanity.playground.logger ||= ActionController::Base.logger
Vanity.playground.load_path = "#{RAILS_ROOT}/experiments"

# Include in controller, add view helper methods.
ActionController::Base.class_eval do
  include Vanity::Rails
  helper Vanity::Rails
end
