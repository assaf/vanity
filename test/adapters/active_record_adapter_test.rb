require "test_helper"
require 'adapters/shared_tests'

describe Vanity::Adapters::ActiveRecordAdapter do

  def adapter
    Vanity::Adapters::ActiveRecordAdapter.new({})
  end

  include Vanity::Adapters::SharedTests

end
