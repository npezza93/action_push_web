class ApplicationPushSubscription < ActionPushWeb::Subscription
  # Customize TokenError handling (default: destroy!)
  rescue_from (ActionPushWeb::TokenError) { }
end
