require 'test/test_helper'
require 'mongo'

class MongodbAdapterTest < Test::Unit::TestCase
  def setup
    @connection = Vanity::Adapters::MongodbAdapter.new({})
    @connection.ab_show("foo_experiment", "foo_id", "foo_alternative")
  end

  def test_alternative_assigned_to
    assert_equal "foo_alternative", @connection.alternative_assigned_to("foo_experiment", "foo_id")
  end
end
