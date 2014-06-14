require "test_helper"

describe Vanity::Adapters::RedisAdapter do
  before do
    require "redis"
    require "redis/namespace"
  end

  it "warns on disconnect error" do
    if defined?(Redis)
      assert_silent do
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

  it "connects to existing redis" do
    mocked_redis = stub("Redis")
    adapter = Vanity::Adapters.redis_connection(:redis => mocked_redis)
    assert_equal mocked_redis, adapter.redis
  end

  it "gracefully fails in #metric_track" do
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:incrby).raises(RuntimeError)

    assert_silent do
      redis_adapter.metric_track("metric", Time.now.to_s, "3ff62e2fb51f0b22646a342a2d357aec", [1])
    end
  end

  it "gracefully fails in #set experiment created at" do
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:setnx).raises(RuntimeError)

    assert_silent do
      redis_adapter.set_experiment_created_at("price_options", Time.now)
    end
  end

  it "gracefully fails in #is_experiment_completed?" do
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:exists).raises(RuntimeError)

    assert_silent do
      redis_adapter.is_experiment_completed?("price_options")
    end
  end

  it "gracefully fails in #ab_show" do
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:[]=).raises(RuntimeError)

    assert_silent do
      redis_adapter.ab_show("price_options", "3ff62e2fb51f0b22646a342a2d357aec", 0)
    end
  end

  it "gracefully fails in #ab_showing" do
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:[]).raises(RuntimeError)

    assert_silent do
      redis_adapter.ab_showing("price_options", "3ff62e2fb51f0b22646a342a2d357aec")
    end
  end

  it "gracefully fails in #ab_not_showing" do
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:del).raises(RuntimeError)

    assert_silent do
      redis_adapter.ab_not_showing("price_options", "3ff62e2fb51f0b22646a342a2d357aec")
    end
  end

  it "gracefully fails in #ab_add_participant" do
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:sadd).raises(RuntimeError)

    assert_silent do
      redis_adapter.ab_add_participant("price_options", "3ff62e2fb51f0b22646a342a2d357aec", 0)
    end
  end

  it "gracefully fails in #ab_seen" do
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:sismember).raises(RuntimeError)

    assert_silent do
      redis_adapter.ab_seen("price_options", "3ff62e2fb51f0b22646a342a2d357aec", 0)
    end
  end

  it "gracefully fails in #ab_assigned" do
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:sismember).raises(RuntimeError)

    assert_silent do
      redis_adapter.ab_assigned("price_options", "3ff62e2fb51f0b22646a342a2d357aec")
    end
  end

  it "gracefully fails in #ab_add_conversion" do
    redis_adapter, mocked_redis = stub_redis
    mocked_redis.stubs(:sismember).raises(RuntimeError)

    assert_silent do
      redis_adapter.ab_add_conversion("price_options", 0, "3ff62e2fb51f0b22646a342a2d357aec")
    end
  end

end
