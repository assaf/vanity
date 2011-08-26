require "action_controller/railtie"
require "action_mailer/railtie"
require "active_record/railtie"
require "vanity/railtie"

module MyApp
  class Application < Rails::Application
    config.session_store :cookie_store, :key=>"_myapp_session", :secret=>"Stay hungry. Stay foolish. -- Steve Jobs"
    config.active_record.logger = $logger
    config.active_record.establish_connection :adapter=>"mysql", :database=>"vanity_test"
    config.active_support.deprecation = :stderr
  end
end

Rails.application.config.root = File.dirname(__FILE__) + "/.."
require File.expand_path("test/myapp/config/routes")

# Initialize the rails application
MyApp::Application.initialize!
