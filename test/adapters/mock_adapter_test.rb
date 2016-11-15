require 'test_helper'
require 'adapters/shared_tests'

describe Vanity::Adapters::MockAdapter do

  def adapter
    Vanity::Adapters::MockAdapter.new({})
  end

  include Vanity::Adapters::SharedTests

end
