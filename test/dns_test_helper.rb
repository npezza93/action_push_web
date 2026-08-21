module DnsTestHelper
  private

    # Surfguard resolves through Resolv.getaddresses, which honours /etc/hosts and
    # search domains and returns every address a host answers with.
    def stub_dns_resolution(*ips)
      dns_mock = mock("dns")
      dns_mock.stubs(:each_address).multiple_yields(*ips)
      Resolv::DNS.stubs(:open).yields(dns_mock)
      Resolv.stubs(:getaddresses).returns(ips.map(&:to_s))
    end

    # A host that resolves to nothing: the resolver errors (timeout/NXDOMAIN),
    # which Surfguard catches and reports as Unresolvable, distinct from a host
    # that resolves only to blocked addresses.
    def stub_dns_failure(error = Resolv::ResolvError)
      Resolv.stubs(:getaddresses).raises(error)
    end
end
