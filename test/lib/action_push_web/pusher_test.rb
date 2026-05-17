require "test_helper"

module ActionPushWeb
  class PusherTest < ActiveSupport::TestCase
    test "pins connection to resolved endpoint IP" do
      subscription = action_push_web_subscriptions(:iphone)
      notification = SubscriptionNotification.new(
        notification: Notification.new(title: "Hi!", path: "/home"),
        subscription:
      )

      stub_dns_resolution("93.184.216.34")
      request = stub_request(:post, subscription.endpoint).
        with(ipaddr: "93.184.216.34").
        to_return(status: 201)

      Pusher.new(ActionPushWeb.config_for(nil), notification).push(connection: Net::HTTP::Persistent.new)

      assert_requested request
    end
  end
end
