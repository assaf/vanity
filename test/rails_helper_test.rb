require "test/test_helper"

class RailsHelperTest < ActionView::TestCase
  include Vanity::Rails::Helpers

  def setup
    super
    metric :sugar_high
    new_ab_test :pie_or_cake do
      metrics :sugar_high
      identify { '1' }
      alternatives :pie, :cake
    end
  end

  def test_ab_test_returns_one_of_the_alternatives
    assert [:pie, :cake].include?(ab_test(:pie_or_cake))
  end

  def test_ab_test_using_js_returns_the_same_alternative
    Vanity.playground.use_js!
    result = ab_test(:pie_or_cake)
    assert [:pie, :cake].include?(result)
    10.times do 
      assert result == ab_test(:pie_or_cake)
    end
  end
end
