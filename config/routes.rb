Rails.application.routes.draw do
  root "home#index"

  get "export_import" => "export_import#index"
  get "export_import/export"
  post "export_import/import"

  resource :session
  resources :passwords, param: :token

  resources :categories, only: [ :index, :create, :update, :destroy ] do
    resources :notes do
      member do
        put :sort
      end
    end
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "up" => "rails/health#show", as: :rails_health_check
end
