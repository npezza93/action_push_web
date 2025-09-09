# frozen_string_literal: true

module ActionPushWeb
  class VapidKey
    attr_reader :ec_key, :public_key, :private_key

    def initialize(public_key, private_key)
      @public_key = public_key
      @private_key = private_key
    end

    # For request header (unpadded)
    def public_key_for_push_header
      public_key.delete("=")
    end

    def ec_key
      @ec_key ||= begin
        group      = OpenSSL::PKey::EC::Group.new("prime256v1")
        public_point  = OpenSSL::PKey::EC::Point.new(group, decode_base64url_to_big_number(public_key))
        priv_bn    = decode_base64url_to_big_number(private_key)

        asn1 = OpenSSL::ASN1::Sequence([
          OpenSSL::ASN1::Integer(1),
          OpenSSL::ASN1::OctetString(priv_bn.to_s(2)),
          OpenSSL::ASN1::ObjectId("prime256v1", 0, :EXPLICIT),
          OpenSSL::ASN1::BitString(public_point.to_octet_string(:uncompressed), 1, :EXPLICIT)
        ])

        OpenSSL::PKey::EC.new(asn1.to_der)
      end
    end

    private

    def decode_base64url_to_big_number(str)
      OpenSSL::BN.new(Base64.urlsafe_decode64(str), 2)
    end
  end
end
