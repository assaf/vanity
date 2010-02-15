require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.frameworks -= [ :active_record, :active_resource, :action_mailer ]
  config.action_controller.session = { :key=>"_myapp_session", :secret=>"Stay hungry. Stay foolish. -- Steve Jobs" }
  config.after_initialize do
    $:.unshift File.dirname(__FILE__) + "/../../../lib/"
    require "vanity"
  end
end
