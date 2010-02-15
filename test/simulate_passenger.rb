$:.unshift "#{File.dirname(__FILE__)}/../lib"
require "phusion_passenger/spawn_manager"
require "phusion_passenger/railz/application_spawner"
require "mocha"
require "vanity" 

app_root = File.expand_path("myapp", File.dirname(__FILE__))
server = PhusionPassenger::Railz::ApplicationSpawner.new app_root, "spawn_method"=>"smart-lv2"
server.send(:define_message_handler, :vanity_test, :handle_vanity_test)

class << server
  def handle_vanity_test
    client.write Vanity.playground.redis.object_id
  end
end

source_connection = Vanity.playground.redis.object_id
begin
    server.start
    server.spawn_application
    sleep 0.1 until server.started?
		server.send(:server).write("vanity_test")
    forked_connection = server.send(:server).read
ensure
  server.stop
end
assert source_connection
assert forked_connection
refute_equal source_connection, forked_connection
