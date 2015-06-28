require "test_helper"

describe Vanity::Connection do
  describe "#new" do
    it "establishes connection with default specification" do
      Vanity::Adapters.expects(:establish_connection).with(adapter: "redis")
      Vanity::Connection.new
    end

    it "establishes connection given a connection specification" do
      Vanity::Adapters.expects(:establish_connection).with(adapter: "mock")
      Vanity::Connection.new(adapter: "mock")
    end

    it "can skip connection" do
      Vanity::Autoconnect.stubs(:playground_should_autoconnect?).returns(false)
      connection = Vanity::Connection.new(adapter: "mock")
      assert !connection.connected?
    end

    it "parses from a string" do
      Vanity::Adapters.expects(:establish_connection).with(
        adapter: 'redis',
        username: 'user',
        password: 'secrets',
        host: 'redis.local',
        port: 6379,
        path: '/5',
        params: nil
      )
      Vanity::Connection.new("redis://user:secrets@redis.local:6379/5")
    end

    it "raises an error for invalid specification hashes" do
      assert_raises(Vanity::Connection::InvalidSpecification) {
        Vanity::Connection.new("adapter" => "mock")
      }
    end

    it "allows a redis connection to be specified" do
      redis = stub("Redis")
      Vanity::Adapters.expects(:establish_connection).with(adapter: :redis, redis: redis)
      Vanity::Connection.new(redis: redis)
    end
  end
end