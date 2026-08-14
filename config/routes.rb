Rails.application.routes.draw do
  root "sessions#new"

  resource :session, only: %i[new create destroy]
  get "sign-in/:public_id", to: "sign_ins#show", as: :sign_in
  post "sign-in/:public_id", to: "sign_ins#create", as: :consume_sign_in

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
