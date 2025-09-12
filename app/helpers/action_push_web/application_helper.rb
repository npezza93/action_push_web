module ActionPushWeb
  module ApplicationHelper
    def action_push_web_key_tag(application: nil)
      tag.meta name: "action-push-web-public-key",
        content: ActionPushWeb.config_for(application)[:public_key]
    end

    def when_web_notifications_disabled(**attrs, &block)
      content_tag("action-push-web-denied", capture(&block), **attrs)
    end

    def when_web_notifications_allowed(href: action_push_web.subscriptions_path,
      service_worker_url: pwa_service_worker_path(format: :js), **attrs, &block)
      content_tag("action-push-web-granted", capture(&block),
        href:, service_worker_url:, **attrs)
    end

    def ask_for_web_notifications(**attrs, &block)
      content_tag("action-push-web-request", capture(&block), **attrs)
    end
  end
end
