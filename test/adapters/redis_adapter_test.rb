require 'test/test_helper'

class RedisAdapterTest < Test::Unit::TestCase
  def setup
    require "vanity/adapters/redis_adapter"
    require "redis"
    require "redis/namespace"
  end

  def test_warn_on_disconnect_error
    if defined?(Redis)
      assert_nothing_raised do
        Redis.any_instance.stubs(:connect!)
        mocked_redis = stub("Redis")
        mocked_redis.expects(:client).raises(RuntimeError)
        redis_adapter = Vanity::Adapters::RedisAdapter.new({})
        redis_adapter.stubs(:redis).returns(mocked_redis)
        redis_adapter.expects(:warn).with("Error while disconnecting from redis: RuntimeError")
        redis_adapter.disconnect!
      end
    end
  end

  def stub_redis
    Vanity.playground.failover_on_datastore_error!
    mocked_redis = stub("Redis")
    redis_adapter = Vanity::Adapters::RedisAdapter.new(:redis => mocked_redis)

    [redis_adapter, mocked_redis]
  end

  def test_graceful_failure_metric_track
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:incrby).raises(RuntimeError)

    assert_nothing_raised do
      redis_adapter.metric_track("metric", Time.now.to_s, "3ff62e2fb51f0b22646a342a2d357aec", [1])
    end
  end

  def test_graceful_failure_set_experiment_created_at
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:setnx).raises(RuntimeError)

    assert_nothing_raised do
      redis_adapter.set_experiment_created_at("price_options", Time.now)
    end
  end

  def test_graceful_failure_is_experiment_completed?
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:exists).raises(RuntimeError)

    assert_nothing_raised do
      redis_adapter.is_experiment_completed?("price_options")
    end
  end

  def test_graceful_failure_ab_show
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:[]=).raises(RuntimeError)

    assert_nothing_raised do
      redis_adapter.ab_show("price_options", "3ff62e2fb51f0b22646a342a2d357aec", 0)
    end
  end

  def test_graceful_failure_ab_showing
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:[]).raises(RuntimeError)

    assert_nothing_raised do
      redis_adapter.ab_showing("price_options", "3ff62e2fb51f0b22646a342a2d357aec")
    end
  end

  def test_graceful_failure_ab_not_showing
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:del).raises(RuntimeError)

    assert_nothing_raised do
      redis_adapter.ab_not_showing("price_options", "3ff62e2fb51f0b22646a342a2d357aec")
    end
  end

  def test_graceful_failure_ab_add_participant
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:sadd).raises(RuntimeError)

    assert_nothing_raised do
      redis_adapter.ab_add_participant("price_options", "3ff62e2fb51f0b22646a342a2d357aec", 0)
    end
  end

  def test_graceful_failure_ab_seen
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:sismember).raises(RuntimeError)

    assert_nothing_raised do
      redis_adapter.ab_seen("price_options", "3ff62e2fb51f0b22646a342a2d357aec", 0)
    end
  end

  def test_graceful_failure_ab_assigned
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:sismember).raises(RuntimeError)

    assert_nothing_raised do
      redis_adapter.ab_assigned("price_options", "3ff62e2fb51f0b22646a342a2d357aec")
    end
  end

  def test_graceful_failure_ab_add_conversion
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:sismember).raises(RuntimeError)

    assert_nothing_raised do
      redis_adapter.ab_add_conversion("price_options", 0, "3ff62e2fb51f0b22646a342a2d357aec")
    end
  end

end
