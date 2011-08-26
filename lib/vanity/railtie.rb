require "vanity"
require "vanity/frameworks/rails"
require "rails/railtie"

module Vanity
  class Railtie < ::Rails::Railtie
    config.vanity = Vanity.playground
    initializer "vanity.load" do |app|
      Vanity::Rails.load!
    end
  end
end
