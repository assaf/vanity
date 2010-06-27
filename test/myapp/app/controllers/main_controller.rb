class MainController < ApplicationController
  def index
    render :text=>"#{Vanity.playground.connection}\n#{Vanity.playground.connection.redis.object_id}"
   rescue Error=>ex
     puts $!
  end
end
