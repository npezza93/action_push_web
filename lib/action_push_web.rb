require "zeitwerk"
require "action_push_web/engine"
require "action_push_web/errors"
require "net/http"
require "net/http/persistent"
require "jwt"

loader= Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/action_push_web/errors.rb")
loader.setup

module ActionPushWeb
  def self.pool
    @pool ||= Pool.new(
        invalid_subscription_handler: ->(subscription_id) do
          Rails.application.executor.wrap do
            ActionPushWeb::Subscription.find_by(id: subscription_id)&.destroy
          end
        end)
  end

  def self.config_for(application)
    platform_config = Rails.application.config_for(:push)[:web]
    raise "ActionPushWeb: 'web' platform is not configured" unless platform_config.present?

    if application.present?
      notification_config = platform_config.fetch(application.to_sym, {})
      platform_config.fetch(:application, {}).merge(notification_config)
    else
      platform_config
    end
  end

  def self.push(notification)
    pool.enqueue(notification, config: self.config_for(notification.application))
  end
end
