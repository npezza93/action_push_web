module ActionPushWeb
  class SubscriptionNotification
    def initialize(notification:, subscription:)
      @notification = notification
      @subscription = subscription
    end

    attr_reader :notification, :subscription

    delegate :application, to: :notification
    delegate :title, :body, :icon_path, :path, :badge, :context, to: :notification
    delegate :endpoint, :p256dh_key, :auth_key, to: :subscription
  end
end
