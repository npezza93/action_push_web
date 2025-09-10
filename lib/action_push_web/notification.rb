module ActionPushWeb
  class Notification
    extend ActiveModel::Callbacks

    attr_accessor :title, :body, :badge, :icon_path, :path, :context, :urgency

    define_model_callbacks :delivery

    class_attribute :queue_name, default: ActiveJob::Base.default_queue_name
    class_attribute :enabled, default: !Rails.env.test?
    class_attribute :application

    class << self
      def queue_as(name)
        self.queue_name = name
      end
    end

    def initialize(title:, path:, body: nil, icon_path: nil, badge: nil, urgency: nil, **context)
      @title, @body, @path, @icon_path, @badge, @urgency = title, body, path, icon_path, badge, urgency
      @context = context
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
      { title:, body:, path:, badge:, **context }.compact
    end
  end
end
