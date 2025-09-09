Rails.application.routes.draw do
  resources :comments
  resources :push_subscriptions, only: :create
  root to: "comments#index"
  get "service-worker" => "pwa#service_worker"
end
