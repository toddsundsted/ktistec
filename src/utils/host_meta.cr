module Ktistec
  # A [Web Host Metadata](https://tools.ietf.org/html/rfc6415)
  # client.
  module HostMeta
    # Returns the result of querying the specified host.
    #
    #     h = Ktistec::HostMeta.query("epiktistes.com") # => #<Ktistec::HostMeta::Result:0x10e99...>
    #     h.links("lrdd").first.template # => "https://epiktistes.com/.well-known/webfinger?resource={uri}"
    #
    # Raises `Ktistec::HostMeta::NotFoundError` if the host does not exist and
    # `Ktistec::HostMeta::RedirectionError` if redirection fails. Otherwise,
    # returns `Ktistec::HostMeta::Result`.
    #
    def self.query(host, *args)
      Client.query(host, *args)
    end
  end
end

require "./host_meta/client"
require "./host_meta/result"
