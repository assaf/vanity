require "phusion_passenger/spawn_manager"
require "phusion_passenger/railz/application_spawner"
require "mocha"
require "vanity" 

app_root = File.expand_path(File.dirname(__FILE__))
server = PhusionPassenger::Railz::ApplicationSpawner.new app_root, "spawn_method"=>"smart-lv2"
server.send(:define_message_handler, :vanity_test, :handle_vanity_test)
class << server
  def handle_vanity_test
    client.write Vanity.playground.redis.instance_variable_get(:@sock).addr[1]
  end
end

begin
    server.start
    server.spawn_application
    sleep 0.1 until server.started?
		server.send(:server).write("vanity_test")
    puts server.send(:server).read
   
ensure
  server.stop
end
