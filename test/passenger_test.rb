require "test/test_helper"

# Not supported for rails3
if !defined?(Rails::Railtie) && ActiveRecord::Base.connected?
  require "phusion_passenger/spawn_manager"

  class PassengerTest < Test::Unit::TestCase
    def setup
      super
      ActiveRecord::Base.connection.disconnect! # Otherwise AR metric tests fail
      @original = Vanity.playground.connection
      File.unlink "test/myapp/config/vanity.yml" rescue nil
      File.open("test/myapp/config/vanity.yml", "w") do |io|
	io.write YAML.dump({ "production"=>DATABASE })
      end
      @server = PhusionPassenger::SpawnManager.new
      @server.start
      Thread.pass until @server.started?
      app_root = File.expand_path("myapp", File.dirname(__FILE__))
      @app = @server.spawn_application "app_root"=>app_root, "spawn_method"=>"smart"
    end

    def test_reconnect
      # When using AR adapter, we're not responsible to reconnect, and we're going
      # to get the same "connect" (AR connection handler) either way.
      # return if defined?(Vanity::Adapters::ActiveRecordAdapter) && Vanity::Adapters::ActiveRecordAdapter === Vanity.playground.connection

      sleep 0.1
      case @app.listen_socket_type
      when "tcp" ; socket = TCPSocket.new(*@app.listen_socket_name.split(":"))
      when "unix"; socket = UNIXSocket.new(@app.listen_socket_name)
      else fail
      end
      channel = PhusionPassenger::MessageChannel.new(socket)
      request = {"REQUEST_PATH"=>"/", "REQUEST_METHOD"=>"GET", "QUERY_STRING"=>" "}
      channel.write_scalar request.to_a.join("\0")
      response = socket.read.split("\r\n\r\n").last
      socket.close
      conn, obj_id = response.split("\n")
      assert_equal @original.to_s, conn
      assert_not_equal @original.object_id.to_s, obj_id
    end

    def teardown
      super
      @server.cleanup
      @server.stop
      Process.kill('SIGKILL', @app.pid.to_i) # Just in case...KIDS, GET OUT OF THE POOL!
      File.unlink "test/myapp/config/vanity.yml"
    end
  end
end
