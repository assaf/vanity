require 'test/test_helper'

class AbstractAdapterTest < Test::Unit::TestCase
  def setup
    @connection = Vanity::Adapters::AbstractAdapter.new
  end

  def test_alternative_assigned_to
    assert_raise RuntimeError do
      @connection.alternative_assigned_to("foo_experiment", "foo_id")
    end
  end
end
