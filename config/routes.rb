Rails.application.routes.draw do
  get 'reports/index'
  get 'orders/new'
  get 'orders/create'
  
  root to: 'products#index'
  
  
  resources :products

  resources :orders, only: [:new, :create]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check


  get "/reports", to: "reports#index", as: :reports

end
