require "web_finger"

module Ktistec
  # Utilities for network operations.
  #
  module Network
    # Resolves the name of a resource to the network IRI of the
    # resource.
    #
    # Returns the IRI if successful. Raises an error if things go wrong:
    #
    #   HostMeta::Error, WebFinger::Error - the underlying lookup failed
    #
    #   KeyError - a rel="self" link does not exist in the retrieved record
    #
    #   NilAssertionError - the href attribute is blank
    #
    def self.resolve(name)
      url = URI.parse(name)
      if url.scheme && url.host && url.path
        name
      else
        WebFinger.query("acct:#{name.lchop('@')}").link("self").href.presence.not_nil!
      end
    end
  end
end
