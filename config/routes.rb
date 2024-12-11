Rails.application.routes.draw do
  root "home#index"
  
  resource :session
  resources :passwords, param: :token
  
  resources :categories do
    resources :notes
  end
  
  get "up" => "rails/health#show", as: :rails_health_check
end
