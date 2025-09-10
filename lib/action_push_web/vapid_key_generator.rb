module ActionPushWeb
  class VapidKeyGenerator
    def initialize
      @ec_key = OpenSSL::PKey::EC.generate("prime256v1")
    end

    def private_key
      Base64.urlsafe_encode64(ec_key.private_key.to_s(2))
    end

    def public_key
      Base64.urlsafe_encode64(ec_key.public_key.to_bn.to_s(2))
    end

    private

    attr_reader :ec_key
  end
end
