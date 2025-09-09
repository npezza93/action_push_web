# frozen_string_literal: true

module ActionPushWeb
  class TokenError < StandardError; end
  class ExpiredSubscription < StandardError; end
  class InvalidSubscription < StandardError; end
  class Unauthorized < StandardError; end
  class PayloadTooLarge < StandardError; end
  class TooManyRequests < StandardError; end
  class PushServiceError < StandardError; end
  class ResponseError < StandardError; end
end
