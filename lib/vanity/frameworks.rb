# TODO turn this into a real rails engine jobbie
# Automatically configure Vanity.
if defined?(Rails)
  class Plugin < Rails::Railtie # :nodoc:
    initializer "vanity.require" do |app|
      require 'vanity/frameworks/rails'

      Vanity::Rails.load!
    end
  end
end
