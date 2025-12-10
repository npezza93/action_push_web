module ActionPushWeb
  class SubscriptionsController < ApplicationController
    def create
      ApplicationPushSubscription.create_with(user_agent: request.user_agent).
        create_or_find_by!(push_subscription_params)
    end

    private

      def push_subscription_params
        params.expect(push_subscription: %i[endpoint p256dh_key auth_key])
      end
  end
end
