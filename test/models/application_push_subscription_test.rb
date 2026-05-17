require "test_helper"

class ApplicationPushSubscriptionTest < ActiveSupport::TestCase
  test "TokenErrors are ignored" do
    ActionPushWeb.pool = ActionPushWeb::Pool.new(delivery_pool: InlinePoolExecutor.new)

    stub_dns_resolution("93.184.216.34")
    stub_request(:post, "https://web.push.apple.com/ghi").to_return(status: 404)

    notification = ActionPushWeb::Notification.new(title: "Hi!", path: "/home")
    iphone = application_push_subscriptions(:iphone_other)

    assert_no_difference -> { ApplicationPushSubscription.count } do
      iphone.push(notification)
    end
    assert_not iphone.destroyed?
  end
end
