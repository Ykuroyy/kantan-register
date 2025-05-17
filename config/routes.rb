Rails.application.routes.draw do
  root "products#index"

  resources :products do
    patch :remove_image, on: :member
  end


  resources :orders, only: [:new, :create]
  
  get "/reports", to: "reports#index", as: :reports

  get "up" => "rails/health#show", as: :rails_health_check

end




