require "test_helper"

class VanityMailer < ActionMailer::Base
  include Vanity::Rails::Helpers
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::TagHelper

  def ab_test_subject(user)
    use_vanity_mailer user

    mail :subject =>ab_test(:pie_or_cake).to_s, :body => ""
  end

  def ab_test_content(user)
    use_vanity_mailer user

    mail do |format|
      format.html { render :text=>view_context.vanity_tracking_image(Vanity.context.vanity_identity, :open, :host => "127.0.0.1:3000") }
    end
  end
end

class UseVanityMailerTest < ActionMailer::TestCase
  tests VanityMailer

  def setup
    super
    metric :sugar_high
    new_ab_test :pie_or_cake do
      metrics :sugar_high
      alternatives :pie, :cake
      default :pie
    end
  end

  def test_js_enabled_still_adds_participant
    Vanity.playground.use_js!
    experiment(:pie_or_cake).identify { }
    experiment(:pie_or_cake).chooses(:pie)
    VanityMailer.ab_test_subject(nil)


    alts = experiment(:pie_or_cake).alternatives
    assert_equal 1, alts.map(&:participants).sum
  end

  def test_returns_different_alternatives
    experiment(:pie_or_cake).identify { }

    experiment(:pie_or_cake).chooses(:pie)
    email = VanityMailer.ab_test_subject(nil)
    assert_equal 'pie', email.subject

    experiment(:pie_or_cake).chooses(:cake)
    email = VanityMailer.ab_test_subject(nil)
    assert_equal 'cake', email.subject
  end

  def test_tracking_image_is_rendered
    email = VanityMailer.ab_test_content(nil)
    assert email.body =~ /<img/
    assert email.body =~ /_identity=/
  end
end
