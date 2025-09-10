require "test_helper"

class ActionPushWeb::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "#create for new subscription" do
    assert_difference -> { ApplicationPushSubscription.count }, 1 do
      post action_push_web.subscriptions_path, params: { push_subscription: {
        endpoint: "https://web.push.apple.com/abc", p256dh_key: "abc", auth_key: "abc"
      } }

      assert_response :ok
    end
  end

  test "#create for existing subscription" do
    subscription = action_push_web_subscriptions(:iphone)

    assert_no_difference -> { ApplicationPushSubscription.count } do
      post action_push_web.subscriptions_path, params: { push_subscription: {
        **subscription.attributes.symbolize_keys.slice(:endpoint, :p256dh_key, :auth_key)
      } }

      assert_response :ok
    end
  end
end
