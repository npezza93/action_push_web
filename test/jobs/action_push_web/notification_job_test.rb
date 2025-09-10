require "test_helper"

module ActionPushWeb
  class NotificationJobTest < ActiveSupport::TestCase
    setup do
      @notification_attributes = { title: "Hi!", body: "This is a push notification", path: "/home" }
    end

    test "429 errors are retried with an exponential backoff delay" do
      subscription = action_push_web_subscriptions(:iphone)
      Notification.any_instance.stubs(:deliver_to).raises(TooManyRequestsError)

      assert_enqueued_jobs 1, only: ActionPushWeb::NotificationJob do
        ActionPushWeb::NotificationJob.perform_later("ApplicationPushWebNotification", @notification_attributes, subscription)
      end

      [ 1, 2, 4, 8, 16 ].each do |minutes|
        perform_enqueued_jobs only: ActionPushWeb::NotificationJob
        assert_wait minutes.minutes
      end

      Notification.any_instance.stubs(:deliver_to)
      ActionPushWeb::NotificationJob.perform_now("ApplicationPushWebNotification", @notification_attributes, subscription)
      perform_enqueued_jobs only: ActionPushWeb::NotificationJob
      assert_enqueued_jobs 0, only: ActionPushWeb::NotificationJob
    end

    test "ActiveJob::DeserializationError errors are discarded" do
      subscription = action_push_web_subscriptions(:iphone).dup.tap(&:save!)
      Notification.any_instance.stubs(:deliver_to).raises(TokenError)

      subscription.destroy
      assert_enqueued_jobs 1, only: ActionPushWeb::NotificationJob do
        ActionPushWeb::NotificationJob.perform_later("ApplicationPushWebNotification", @notification_attributes, subscription)
      end
      perform_enqueued_jobs only: ActionPushWeb::NotificationJob
      assert_enqueued_jobs 0, only: ActionPushWeb::NotificationJob
    end

    test "Response errors are retried" do
      subscription = action_push_web_subscriptions(:iphone)
      stub_request(:post, "https://web.push.apple.com/abc").to_return(status: 500)

      ActionPushWeb.pool = ActionPushWeb::Pool.new(delivery_pool: InlinePoolExecutor.new)

      assert_enqueued_jobs 1, only: ActionPushWeb::NotificationJob do
        ActionPushWeb::NotificationJob.perform_later("ApplicationPushWebNotification", @notification_attributes, subscription)
      end
      perform_enqueued_jobs only: ActionPushWeb::NotificationJob
      assert_enqueued_jobs 1, only: ActionPushWeb::NotificationJob
    end

    private
      def assert_wait(seconds)
        job = enqueued_jobs_with(only: ActionPushWeb::NotificationJob).last
        delay = job["scheduled_at"].to_time - job["enqueued_at"].to_time
        assert_in_delta seconds, delay, 0.15 * delay, "Expected job to wait approximately #{seconds} seconds, but waited #{delay} seconds instead."
      end
  end
end
