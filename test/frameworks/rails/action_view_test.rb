require "test_helper"

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

  def test_ab_test_adds_participant_to_experiment
    ab_test(:pie_or_cake)
    assert_equal 1, experiment(:pie_or_cake).alternatives.map(&:participants).sum
  end

  def test_vanity_track_url_for_returns_url_with_identity_and_metrics
    self.expects(:url_for).with(:controller => "controller", :action => "action", :_identity => '123', :_track => :sugar_high)
    vanity_track_url_for("123", :sugar_high, :controller => "controller", :action => "action")
  end

  def test_vanity_tracking_image
    self.expects(:url_for).with(:controller => :vanity, :action => :image, :_identity => '123', :_track => :sugar_high).returns("/url")
    assert_equal image_tag("/url", :width => "1px", :height => "1px", :alt => ""), vanity_tracking_image("123", :sugar_high, options = {})
  end

  def test_vanity_experiments
    result = ab_test(:pie_or_cake)
    test_description = ''
    vanity_experiments.each do |name, alternative|
      test_description += "Experiment #{name} chose #{alternative.value}"
    end
    assert_equal test_description, "Experiment pie_or_cake chose #{result}"
  end

  def test_vanity_experiments_return_is_read_only
    result = ab_test(:pie_or_cake)
    vanity_experiments_returns = vanity_experiments
    vanity_experiments_returns[:some_new_key] = 'some new value'
    assert_equal vanity_experiments.keys.length, 1
  end

  def test_vanity_experiments_returns_empty_hash_when_no_experiments
    assert_equal vanity_experiments, {}
  end

end
