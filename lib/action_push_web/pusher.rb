module ActionPushWeb
  class Pusher
    def initialize(config, notification)
      @config = config
      @notification = notification
    end

    def push(connection:)
      request = Net::HTTP::Post.new(uri.request_uri, headers).tap do
        it.body = payload
      end

      connection.request(uri, request).tap { handle_response(it) }
    rescue OpenSSL::OpenSSLError
      raise TokenError.new
    end

    private

    attr_reader :config, :notification

    delegate :title, :body, :icon_path, :path, :badge, :endpoint, :p256dh_key,
      :auth_key, to: :notification

    def message
      JSON.generate title:, options: { body:, icon: icon_path, data: { path:, badge: } }
    end

    def payload
      @payload ||= PayloadEncryption.new(message:, p256dh_key:, auth_key:).encrypt
    end

    def vapid_identification
      config.slice(:public_key, :private_key).compact
    end

    def uri
      @uri ||= URI.parse(endpoint)
    end

    def headers
      headers = {}
      headers["Content-Type"]     = "application/octet-stream"
      headers["Urgency"]          = notification.urgency.presence || config.fetch(:urgency, :normal).to_s
      headers["Ttl"]              = config.fetch(:ttl, 60 * 60 * 24 * 7 * 4).to_s
      headers["Content-Encoding"] = "aes128gcm"
      headers["Content-Length"]   = payload.length.to_s
      headers["Authorization"]    = vapid_authorization

      headers
    end

    def vapid_authorization
      vapid_key = VapidKey.new(config[:public_key], config[:private_key])

      jwt = JWT.encode(jwt_payload, vapid_key.ec_key,
        "ES256", { "typ": "JWT", "alg": "ES256" })

      "vapid t=#{jwt},k=#{vapid_key.public_key_for_push_header}"
    end

    def jwt_payload
      { aud: uri.scheme + "://" + uri.host,
        exp: Time.now.to_i + config.fetch(:expiration, 12 * 60 * 60),
        sub: config.fetch(:subject, "mailto:sender@example.com") }
    end

    def handle_response(response)
      if response.is_a?(Net::HTTPGone) || response.is_a?(Net::HTTPNotFound) # 410 || 404
        raise TokenError.new
      elsif response.is_a?(Net::HTTPUnauthorized) || response.is_a?(Net::HTTPForbidden) || # 401, 403
            response.is_a?(Net::HTTPBadRequest) && response.message == "UnauthorizedRegistration" # 400, Google FCM
        raise UnauthorizedError.new
      elsif response.is_a?(Net::HTTPRequestEntityTooLarge) # 413
        raise PayloadTooLargeError.new
      elsif response.is_a?(Net::HTTPTooManyRequests) # 429, try again later!
        raise TooManyRequestsError.new
      elsif response.is_a?(Net::HTTPServerError) # 5xx
        raise PushServiceError.new
      elsif !response.is_a?(Net::HTTPSuccess) # unknown/unhandled response error
        raise ResponseError.new
      end
    end
  end
end
