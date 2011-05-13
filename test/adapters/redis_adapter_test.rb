require 'test/test_helper'
require 'redis/namespace'

class RedisAdapterTest < Test::Unit::TestCase
  def setup
    @connection = Vanity::Adapters::RedisAdapter.new({})
    @connection.ab_show("foo_experiment", "foo_id", "foo_alternative")
  end

  def test_alternative_assigned_to
    assert_equal "foo_alternative", @connection.alternative_assigned_to("foo_experiment", "foo_id")
  end
end
