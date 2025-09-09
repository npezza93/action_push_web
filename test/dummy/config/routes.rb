Rails.application.routes.draw do
  resources :comments
  root to: "comments#index"
  get "service-worker" => "pwa#service_worker"
end
