require File.expand_path("test/test_helper")

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
  
  def test_vanity_track_url_for_returns_url_with_identity_and_metrics
    assert_equal vanity_track_url_for("123", :sugar_high, :controller => "controller", :action => "action"), "/controller/action?_identity=123&amp;_track=sugar_high"
  end
  
  def test_vanity_tracking_image
    assert_equal vanity_tracking_image("123", :sugar_high, options = {}), image_tag("/vanity/image?_identity=123&amp;_track=sugar_high", :width => "1px", :height => "1px", :alt => "")
  end
end
