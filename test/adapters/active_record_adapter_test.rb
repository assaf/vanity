require "test_helper"
require 'vanity/adapters/active_record_adapter'
require 'adapters/shared_tests'

describe Vanity::Adapters::ActiveRecordAdapter do

  def specification
    Vanity::Connection::Specification.new(VanityTestHelpers::DATABASE_OPTIONS["active_record"])
  end

  def adapter
    Vanity::Adapters::ActiveRecordAdapter.new(specification.to_h)
  end

  if ENV["DB"] == "active_record"
    include Vanity::Adapters::SharedTests
  end

end
