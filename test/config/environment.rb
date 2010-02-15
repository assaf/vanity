require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.frameworks -= [ :active_record, :active_resource, :action_mailer ]
  config.action_controller.session = { :key=>"_myapp_session", :secret=>"Stay hungry. Stay foolish. -- Steve Jobs" }
  config.after_initialize do
    $:.unshift File.dirname(__FILE__) + "/../../lib/"
    require "vanity"
    puts "Initalized: #{Process.pid}"
  end
end

PhusionPassenger.on_event(:starting_worker_process) do |forked| 
  if forked 
    puts "Forked: #{Process.pid}"
    # We’re in smart spawning mode.
    begin
      #Vanity.playground.reconnect_redis 
    rescue Exception => e
      puts e
      RAILS_DEFAULT_LOGGER.error "Error connecting to redis: #{e.to_s}" 
    end
  else
    puts "Unforked: #{Process.pid}"
  end 
end 
