ActionController::Routing::Routes.draw do |map|
  map.connect "/", :controller=>:main, :action=>:index
end
