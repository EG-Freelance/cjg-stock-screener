Rails.application.routes.draw do 
  if Rails.env == "production"
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
  root 'pages#index'
  devise_for :users
 
  resources :pages
  
  authenticated :user do
    post 'pages/import_pi' => 'pages#import_pi', :as => 'import_pi'
    post 'pages/import_si' => 'pages#import_si', :as => 'import_si'
    post 'pages/auto_import_si' => 'pages#auto_import_si', :as => 'auto_import_si'
    post 'pages/auto_import_earnings_dates' => 'pages#auto_import_ed', :as => 'auto_import_ed'
    get 'analysis' => 'pages#analysis', :as => 'analysis'
    post 'pages/update_display' => 'pages#update_display', :as => 'update_display'
    post 'pages/export_to_excel' => 'pages#export_to_excel', :as => 'export_to_excel'
    post 'pages/export_transactions_to_excel' => 'pages#export_transactions_to_excel', :as => 'export_transactions_to_excel'
    post 'pages/update_action' => 'pages#update_action', :as => 'update_action'
    post 'pages/update_workers' => 'pages#update_workers', :as => 'update_workers'
  end
  
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

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
