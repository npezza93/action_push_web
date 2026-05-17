# Extends WebMock to support ipaddr matching for testing IP pinning.
module WebMock
  class RequestSignature
    attr_accessor :ipaddr
  end

  module RequestPatternIpaddrExtension
    attr_accessor :ipaddr_pattern

    def assign_options(options)
      options = options.dup
      @ipaddr_pattern = options.delete(:ipaddr) || options.delete("ipaddr")
      super(options)
    end

    def matches?(request_signature)
      super && ipaddr_matches?(request_signature)
    end

    private
      def ipaddr_matches?(request_signature)
        @ipaddr_pattern.nil? || @ipaddr_pattern == request_signature.ipaddr
      end
  end

  RequestPattern.prepend RequestPatternIpaddrExtension

  module NetHTTPUtilityIpaddrExtension
    def request_signature_from_request(net_http, request, body = nil)
      super.tap { |signature| signature.ipaddr = net_http.ipaddr }
    end
  end

  NetHTTPUtility.singleton_class.prepend NetHTTPUtilityIpaddrExtension
end
