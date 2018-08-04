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

    image_html = view_context.vanity_tracking_image(Vanity.context.vanity_identity, :open, :host => "127.0.0.1:3000")

    mail do |format|
      format.html { render :html=>image_html.html_safe }
    end
  end
end
