# frozen_string_literal: true

module ActionPushWeb
  class SubscriptionNotification
    def initialize(notification:, subscription:)
      @notification = notification
      @subscription = subscription
    end

    delegate :application, to: :notification
    delegate :title, :body, :icon_path, :path, :badge, to: :notification
    delegate :endpoint, :p256dh_key, :auth_key, to: :subscription

    def destroy_subscription
      subscription.destroy
    end

    def subscription_id
      subscription.id
    end

    private
      attr_reader :notification, :subscription
  end
end
