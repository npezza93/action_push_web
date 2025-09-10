require "test_helper"

module ActionPushWeb
  class SubscriptionTest < ActiveSupport::TestCase
    setup { @notification = ActionPushWeb::Notification.new(title: "Hi!", path: "/home") }

    test "device is destroyed on TokenError" do
      iphone = action_push_web_subscriptions(:iphone)
      stub_request(:post, "https://web.push.apple.com/abc").to_return(status: 404)

      ActionPushWeb.pool = ActionPushWeb::Pool.new(
        delivery_pool: InlinePoolExecutor.new,
        invalidation_pool: InlinePoolExecutor.new
      )

      assert_difference -> { ActionPushWeb::Subscription.count }, -1 do
        iphone.push(@notification)
      end
      assert iphone.destroyed?
    end
  end
end
