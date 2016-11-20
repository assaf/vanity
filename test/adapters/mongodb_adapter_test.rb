require "test_helper"
require 'vanity/adapters/mongodb_adapter'
require 'adapters/shared_tests'

describe Vanity::Adapters::MongodbAdapter do

  def specification
    Vanity::Connection::Specification.new(VanityTestHelpers::DATABASE_OPTIONS["mongodb"])
  end

  def adapter
    Vanity::Adapters::MongodbAdapter.new(specification.to_h)
  end

  if ENV["DB"] == "mongodb"
    include Vanity::Adapters::SharedTests
  end

end
