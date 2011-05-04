require 'test/test_helper'

class RedisAdapterTest < Test::Unit::TestCase
  def test_warn_on_disconnect_error
    assert_nothing_raised do
      Redis.any_instance.stubs(:connect!)
      mocked_redis = stub("Redis")
      mocked_redis.expects(:quit).raises(RuntimeError)
      redis_adapter = Vanity::Adapters::RedisAdapter.new({})
      redis_adapter.expects(:warn).with("Error while disconnecting from redis: RuntimeError")
      redis_adapter.stubs(:redis).returns(mocked_redis)
      redis_adapter.disconnect!
    end
  end
end
