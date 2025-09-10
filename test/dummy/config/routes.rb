Rails.application.routes.draw do
  mount ActionPushWeb::Engine => "/action_push_web"

  resources :comments
  resources :push_subscriptions, only: :create
  root to: "comments#index"
  get "service-worker" => "pwa#service_worker"
end
