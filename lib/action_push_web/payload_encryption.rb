module ActionPushWeb
  class PayloadEncryption
    def initialize(message:, p256dh_key:, auth_key:)
      @message = message
      @p256dh_key = p256dh_key
      @auth_key = auth_key
    end

    def encrypt
      serverkey16bn = [ server_public_key_bn.to_s(16) ].pack("H*")

      rs = encrypted_payload.bytesize
      raise ArgumentError, "encrypted payload is too big" if rs > 4096

      aes128gcmheader = "#{salt}" + [ rs ].pack("N*") +
        [ serverkey16bn.bytesize ].pack("C*") + serverkey16bn

      aes128gcmheader + encrypted_payload
    end

    attr_reader :message, :p256dh_key, :auth_key

    def group_name = "prime256v1"
    def hash = "SHA256"

    def salt
      @salt ||= Random.new.bytes(16)
    end

    def server
      @server ||= OpenSSL::PKey::EC.generate(group_name)
    end

    def server_public_key_bn = server.public_key.to_bn

    def group
      @group ||= OpenSSL::PKey::EC::Group.new(group_name)
    end

    def client_public_key_bn
      @client_public_key_bn ||= OpenSSL::BN.new(Base64.urlsafe_decode64(p256dh_key), 2)
    end

    def client_public_key
      @client_public_key ||= OpenSSL::PKey::EC::Point.new(group, client_public_key_bn)
    end

    def shared_secret
      @shared_secret ||= server.dh_compute_key(client_public_key)
    end

    def prk
      @prk ||= OpenSSL::KDF.hkdf(shared_secret,
        salt: Base64.urlsafe_decode64(auth_key),
        info: "WebPush: info\0" + client_public_key_bn.to_s(2) + server_public_key_bn.to_s(2),
        hash:, length: 32)
    end

    def content_encryption_key
      @content_encryption_key ||= OpenSSL::KDF.hkdf(
        prk, salt:, info: "Content-Encoding: aes128gcm\0", hash:, length: 16
      )
    end

    def nonce
      @nonce ||= OpenSSL::KDF.hkdf(
        prk, salt:, info: "Content-Encoding: nonce\0", hash:, length: 12
      )
    end

    def encrypted_payload
      @encrypted_payload ||= begin
        cipher = OpenSSL::Cipher.new("aes-128-gcm")
        cipher.encrypt
        cipher.key = content_encryption_key
        cipher.iv = nonce
        text = cipher.update(message)
        padding = cipher.update("\2\0")
        e_text = text + padding + cipher.final
        e_tag = cipher.auth_tag

        e_text + e_tag
      end
    end
  end
end
