module ActionPushWeb
  class Subscription < ApplicationRecord
    belongs_to :owner, polymorphic: true, optional: true

    def push(notification)
      ActionPushWeb.push(SubscriptionNotification.new(notification:, subscription: self))
    end
  end
end
