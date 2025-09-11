module ActionPushWeb
  class Notification
    extend ActiveModel::Callbacks

    attr_accessor :title, :body, :path, :context, :urgency, :silent, :badge
    attr_writer   :icon_path

    define_model_callbacks :delivery

    class_attribute :queue_name, default: ActiveJob::Base.default_queue_name
    class_attribute :enabled, default: !Rails.env.test?
    class_attribute :application

    class << self
      def queue_as(name)
        self.queue_name = name
      end
    end

    def initialize(title:, path: nil, body: nil, icon_path: nil, urgency: nil, badge: nil, silent: nil, **context)
      @title = title
      @path = path
      @body = body.to_s
      @icon_path = icon_path
      @urgency = urgency
      @silent = silent
      @badge = badge
      @context = context
    end

    def deliver_to(subscription)
      if enabled
        run_callbacks(:delivery) { subscription.push(self) }
      end
    end

    def deliver_later_to(subscriptions)
      Array(subscriptions).each do |subscription|
        ApplicationPushWebNotificationJob.set(queue: queue_name).perform_later(self.class.name, self.as_json, subscription)
      end
    end

    def icon_path
      @icon_path.presence || config.fetch(:icon_path, nil)
    end

    def urgency
      (@urgency.presence || config.fetch(:urgency, :normal)).to_s
    end

    def as_json
      { title:, body:, path:, icon_path:, urgency:, silent:, badge:, **context }.compact
    end

    private

    def config
      @config ||= ActionPushWeb.config_for(application)
    end
  end
end
