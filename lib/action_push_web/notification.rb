module ActionPushWeb
  class Notification
    extend ActiveModel::Callbacks

    attr_accessor :title, :body, :badge, :icon_path, :path

    define_model_callbacks :delivery

    class_attribute :queue_name, default: ActiveJob::Base.default_queue_name
    class_attribute :enabled, default: !Rails.env.test?
    class_attribute :application

    class << self
      def queue_as(name)
        self.queue_name = name
      end
    end

    def initialize(title:, body: nil, path: nil, icon_path: nil, badge: nil)
      @title, @body, @path, @icon_path, @badge = title, body, path, icon_path, badge
    end

    def deliver_to(subscription)
      if enabled
        run_callbacks(:delivery) { subscription.push(self) }
      end
    end

    def deliver_later_to(subscriptions)
      Array(subscriptions).each do |subscription|
        ApplicationPushNotificationJob.set(queue: queue_name).perform_later(self.class.name, self.as_json, subscription)
      end
    end

    def as_json
      { title:, body:, path:, badge: }.compact
    end
  end
end
