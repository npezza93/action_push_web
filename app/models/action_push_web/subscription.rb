module ActionPushWeb
  class Subscription < ApplicationRecord
    include ActiveSupport::Rescuable

    PERMITTED_ENDPOINT_HOSTS = %w[
      jmt17.google.com
      fcm.googleapis.com
      updates.push.services.mozilla.com
      web.push.apple.com
      notify.windows.com
    ].freeze

    rescue_from(TokenError) { destroy! }

    belongs_to :owner, polymorphic: true, optional: true

    validates :endpoint, presence: true
    validate :validate_endpoint_url

    def push(notification)
      ActionPushWeb.push(SubscriptionNotification.new(notification:, subscription: self))
    end

    private

      def endpoint_uri
        @endpoint_uri ||= URI.parse(endpoint) if endpoint.present?
      rescue URI::InvalidURIError
        nil
      end

      def validate_endpoint_url
        if endpoint_uri.nil?
          errors.add(:endpoint, "is not a valid URL")
        elsif endpoint_uri.scheme != "https"
          errors.add(:endpoint, "must use HTTPS")
        elsif !permitted_endpoint_host?
          errors.add(:endpoint, "is not a permitted push service")
        end
      end

      def permitted_endpoint_host?
        host = endpoint_uri&.host&.downcase
        PERMITTED_ENDPOINT_HOSTS.any? { |permitted| host&.end_with?(permitted) }
      end
  end
end
