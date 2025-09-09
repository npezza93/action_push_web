module ActionPushWeb
  class Subscription < ApplicationRecord
    include ActiveSupport::Rescuable

    rescue_from(TokenError) { destroy! }

    belongs_to :owner, polymorphic: true, optional: true

    def push(notification)
      ActionPushWeb.push(SubscriptionNotification.new(notification:, subscription: self))
    end
  end
end
