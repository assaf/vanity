Dummy::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  get '/use_vanity(/:id(.:format))', controller: :use_vanity, action: :index

  %w(js view_helper_ab_test_js global_ab_test_js model_js).each do |action|
    get "/use_vanity/#{action}(/:id(.:format))", controller: :use_vanity, action: action
  end

  %w(track test_capture test_render test_view).each do |action|
    get "/ab_test/#{action}(/:id(.:format))", controller: :ab_test, action: action
  end

  %w(reset disable enable chooses add_participant complete).each do |action|
    post "/vanity(/#{action}(/:id(.:format)))", controller: :vanity, action: action
  end

  %w(index participant image).each do |action|
    get "/vanity(/#{action}(/:id(.:format)))", controller: :vanity, action: action
  end
end
