class MainController < ApplicationController
  def index
    render text: "#{Vanity.playground.redis.server}\n#{Vanity.playground.redis.object_id}"
  end
end
