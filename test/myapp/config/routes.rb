MyApp::Application.routes.draw do
  match "vanity/:action", :controller=>:vanity
  match "/", :controller=>:main, :action=>:index
  match ':controller(/:action(/:id(.:format)))'
end
