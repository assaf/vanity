require 'test_helper'
require 'adapters/shared_tests'

describe Vanity::Adapters::MockAdapter do

  def specification
    Vanity::Connection::Specification.new(VanityTestHelpers::DATABASE_OPTIONS["mock"])
  end

  def adapter
    Vanity::Adapters::MockAdapter.new({})
  end

  include Vanity::Adapters::SharedTests

end
