module ActionPushWeb
  class TokenError < StandardError; end
  class UnauthorizedError < StandardError; end
  class PayloadTooLargeError < StandardError; end
  class TooManyRequestsError < StandardError; end
  class PushServiceError < StandardError; end
  class ResponseError < StandardError; end
end
