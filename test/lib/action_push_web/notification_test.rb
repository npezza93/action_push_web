require "test_helper"

module ActionPushWeb
  class NotificationTest < ActiveSupport::TestCase
    setup do
      @notification = build_notification
      ActionPushWeb::Notification.enabled = true
    end

    teardown do
      ActionPushWeb::Notification.enabled = false
    end

    test "deliver_to" do
      subscription = action_push_web_subscriptions(:iphone)
      subscription.expects(:push).with(@notification)

      @notification.deliver_to(subscription)
    end

    test "deliver_to is a noop when disabled" do
      ActionPushWeb::Notification.enabled = false
      subscription = action_push_web_subscriptions(:iphone)
      subscription.expects(:push).never

      @notification.deliver_to(subscription)
    end

    test "deliver_later_to" do
      @notification.deliver_later_to([ action_push_web_subscriptions(:iphone), action_push_web_subscriptions(:mac) ])
      assert_enqueued_with job: ApplicationPushWebNotificationJob, args: [ "ActionPushWeb::Notification", @notification.as_json, action_push_web_subscriptions(:mac) ]
      assert_enqueued_with job: ApplicationPushWebNotificationJob, args: [ "ActionPushWeb::Notification", @notification.as_json, action_push_web_subscriptions(:iphone) ]
    end

    test "as_json" do
      notification = ActionPushWeb::Notification.
        new(title: "Hi!", body: "This is a push notification", badge: 1,
            path: "/home", calendar_id: 1)

      expected = { title: "Hi!", body: "This is a push notification", badge: 1,
          path: "/home", calendar_id: 1, urgency: "normal" }

      assert_equal(expected, notification.as_json)
    end

    test "#urgency when set in notification" do
      stub_config("push_urgency.yml")
      notification = ActionPushWeb::Notification.
        new(title: "Hi!", path: "/home", urgency: :stat)

      assert_equal("stat", notification.as_json[:urgency])
    end

    test "#urgency when set in config" do
      stub_config("push_urgency.yml")

      notification = ActionPushWeb::Notification.
        new(title: "Hi!", path: "/home")
      assert_equal("low", notification.as_json[:urgency])
    end

    private
      def build_notification
        ActionPushWeb::Notification.new \
          title: "Hi!",
          body: "This is a push notification",
          badge: 1,
          path: "/home",
          calendar_id: 1
      end

      def stub_config(name)
        Rails.application.stubs(:config_for).returns(YAML.load_file(file_fixture("config/#{name}"), symbolize_names: true))
      end
  end
end
