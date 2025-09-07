Rails.application.routes.draw do
  mount ActionPushWeb::Engine => "/action_push_web"
end
