CaCallowayart::Application.routes.draw do
  get "gallery*tags", to: 'gallery#index', defaults: {
    page: 1, group: 'artists'
  }
  get "gallery", to: 'gallery#index', defaults: {
    group: 'artists'
  }

  get "exhibit/current", to: 'gallery#index', defaults: {
    tags: '/ink', group: 'collection'
  }
  get "search", to: 'gallery#index'

  get "collection*tags", to: 'gallery#index', defaults: {
    group: 'collection'
  }

  get "exhibit/past/(:exhibit)", to: 'gallery#index', defaults: {
    tags: '/exhibit', group: 'exhibits'
  }

  get "listing/:artist/:slug", to: 'listing#index', defaults: {
    group: 'collection'
  }

  get "about",   to: 'home#about'
  get "contact", to: 'home#contact' 

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'home#index'

  # allow for variable number of arguments/tags
  # for gallery; determine if there is a better
  # way to do this
  #get 'gallery*tags', to: 'gallery#index'
 

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
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

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
