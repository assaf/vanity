require "test_helper"
require 'vanity/adapters/mongodb_adapter'
require 'adapters/shared_tests'

describe Vanity::Adapters::MongodbAdapter do

  def adapter
    Vanity::Adapters::MongodbAdapter.new({})
  end

  include Vanity::Adapters::SharedTests

end
