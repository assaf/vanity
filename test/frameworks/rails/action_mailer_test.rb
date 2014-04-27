require "test_helper"

class VanityMailer < ActionMailer::Base
  include Vanity::Rails::Helpers
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::TagHelper

  def ab_test_subject(user, forced_outcome=true)
    use_vanity_mailer user
    experiment(:pie_or_cake).chooses(forced_outcome)

    if defined?(Rails::Railtie)
      mail :subject =>ab_test(:pie_or_cake).to_s, :body => ""
    else
      subject ab_test(:pie_or_cake).to_s
      body ""
    end
  end

  def ab_test_content(user)
    use_vanity_mailer user

    if defined?(Rails::Railtie)
      mail do |format|
        format.html { render :text=>view_context.vanity_tracking_image(Vanity.context.vanity_identity, :open, :host => "127.0.0.1:3000") }
      end
    else
      body vanity_tracking_image(Vanity.context.vanity_identity, :open, :host => "127.0.0.1:3000")
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
    end
  end

  def test_js_enabled_still_adds_participant
    Vanity.playground.use_js!
    rails3? ? VanityMailer.ab_test_subject(nil, true) : VanityMailer.deliver_ab_test_subject(nil, true)

    alts = experiment(:pie_or_cake).alternatives
    assert_equal 1, alts.map(&:participants).sum
  end

  def test_returns_different_alternatives
    email = rails3? ? VanityMailer.ab_test_subject(nil, true) : VanityMailer.deliver_ab_test_subject(nil, true)
    assert_equal 'true', email.subject

    email = rails3? ? VanityMailer.ab_test_subject(nil, false) : VanityMailer.deliver_ab_test_subject(nil, false)
    assert_equal 'false', email.subject
  end

  def test_tracking_image_is_rendered
    email = rails3? ? VanityMailer.ab_test_content(nil) : VanityMailer.deliver_ab_test_content(nil)
    assert email.body =~ /<img/
    assert email.body =~ /_identity=/
  end
end