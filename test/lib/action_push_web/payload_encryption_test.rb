require "test_helper"

class ActionPushWeb::PayloadEncryptionTest < ActiveSupport::TestCase
  setup do
    @ec_key = OpenSSL::PKey::EC.generate("prime256v1")

    @p256dh = Base64.urlsafe_encode64(@ec_key.public_key.to_bn.to_s(2))
    @auth    = Base64.urlsafe_encode64(Random.new.bytes(16))
  end

  test "encrypt round trips" do
    payload = ActionPushWeb::PayloadEncryption.new(
      message: "Hello World",
      p256dh_key: @p256dh,
      auth_key: @auth
    ).encrypt

    assert_equal "Hello World", decrypt(payload)
  end

  test "handles unpadded base64 inputs" do
    unpadded_p256dh = @p256dh.gsub(/=*\z/, "")
    unpadded_auth   = @auth.gsub(/=*\z/, "")

    payload = ActionPushWeb::PayloadEncryption.new(
      message: "Hello World",
      p256dh_key: unpadded_p256dh,
      auth_key: unpadded_auth
    ).encrypt

    assert_equal "Hello World", decrypt(payload)
  end

  test "raises when encrypted payload too big" do
    big_message = "A" * 4096 # ciphertext length = plaintext + 18, so this exceeds 4096
    assert_raises(ArgumentError) do
      ActionPushWeb::PayloadEncryption.new(
        message: big_message,
        p256dh_key: @p256dh,
        auth_key: @auth
      ).encrypt
    end
  end

  private

  def decrypt(payload)
    salt           = payload.byteslice(0, 16)
    rs             = payload.byteslice(16, 4).unpack1("N")
    idlen          = payload.getbyte(20)
    serverkey16bn  = payload.byteslice(21, idlen)
    ciphertext     = payload.byteslice(21 + idlen, rs)

    # sanity check on layout
    assert_equal(21 + idlen + rs, payload.bytesize)

    group = OpenSSL::PKey::EC::Group.new("prime256v1")
    server_public_key_bn = OpenSSL::BN.new(serverkey16bn.unpack1("H*"), 16)
    server_public_key    = OpenSSL::PKey::EC::Point.new(group, server_public_key_bn)

    shared_secret = @ec_key.dh_compute_key(server_public_key)

    client_public_key_bn = @ec_key.public_key.to_bn
    info = "WebPush: info\0" + client_public_key_bn.to_s(2) + server_public_key_bn.to_s(2)

    prk = OpenSSL::KDF.hkdf(
      shared_secret,
      salt: Base64.urlsafe_decode64(@auth),
      info: info,
      hash: "SHA256",
      length: 32
    )

    content_encryption_key = OpenSSL::KDF.hkdf(
      prk, salt: salt, info: "Content-Encoding: aes128gcm\0", hash: "SHA256", length: 16
    )
    nonce = OpenSSL::KDF.hkdf(
      prk, salt: salt, info: "Content-Encoding: nonce\0", hash: "SHA256", length: 12
    )

    secret_data = ciphertext.byteslice(0, ciphertext.bytesize - 16)
    auth_tag    = ciphertext.byteslice(ciphertext.bytesize - 16, 16)

    decipher = OpenSSL::Cipher.new("aes-128-gcm")
    decipher.decrypt
    decipher.key = content_encryption_key
    decipher.iv  = nonce
    decipher.auth_tag = auth_tag

    decrypted = decipher.update(secret_data) + decipher.final

    # trailing \2\0 padding
    assert_equal "\2\0", decrypted.byteslice(-2, 2)

    decrypted.byteslice(0, decrypted.bytesize - 2)
  end
end
