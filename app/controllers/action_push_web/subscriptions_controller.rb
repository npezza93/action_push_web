module ActionPushWeb
  class SubscriptionsController < ApplicationController
    def create
      if subscription = ApplicationPushSubscription.find_by(push_subscription_params)
        subscription.touch
      else
        ApplicationPushSubscription.create! push_subscription_params.merge(user_agent: request.user_agent)
      end

      head :ok
    end

    private

      def push_subscription_params
        params.expect(push_subscription: %i[endpoint p256dh_key auth_key])
      end
  end
end
