require File.join(File.dirname(__FILE__), "../vanity")
require File.join(File.dirname(__FILE__), "rails/helpers")
require File.join(File.dirname(__FILE__), "rails/testing")

# Use Rails logger by default.
Vanity.playground.config[:logger] ||= ActionController::Base.logger
