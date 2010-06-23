class MainController < ApplicationController
  def index
    render :text=>"#{Vanity.playground.redis.id}\n#{Vanity.playground.redis.object_id}"
   rescue Error=>ex
     puts $!
  end
end
