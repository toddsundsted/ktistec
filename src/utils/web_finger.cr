require "uri"

module Ktistec
  # A [WebFinger](https://tools.ietf.org/html/rfc7033)
  # client.
  module WebFinger
    # Returns the result of querying for the specified account.
    #
    # The account should conform to the ['acct' URI
    # Scheme](https://tools.ietf.org/html/rfc7565).
    #
    #     w = Ktistec::WebFinger.query("acct:toddsundsted@epiktistes.com") # => #<Ktistec::WebFinger::Result:0x108d...>
    #     w.link("http://webfinger.net/rel/profile-page").href # => "https://epiktistes.com/@toddsundsted"
    #
    # Raises `Ktistec::WebFinger::NotFoundError` if the account does not exist and
    # `Ktistec::WebFinger::RedirectionError` if redirection fails.  Otherwise,
    # returns `Ktistec::WebFinger::Result`.
    #
    def self.query(account, *args)
      Client.query(account, *args)
    end

    # Resolves the name of a resource to the network IRI of the
    # resource.
    #
    # Returns the IRI if successful. Raises an error if things go wrong:
    #
    #   Ktistec::HostMeta::Error, Ktistec::WebFinger::Error - the underlying lookup failed
    #
    #   KeyError - a rel="self" link does not exist in the retrieved record
    #
    #   NilAssertionError - the href attribute is blank
    #
    def self.resolve(name)
      url = URI.parse(name)
      if url.scheme && (host = url.host) && (path = url.path)
        if path =~ /^\/@([a-zA-Z0-9_]+)\/?$/
          Ktistec::WebFinger.query("acct:#{$1}@#{host}").link("self").href.presence.not_nil!
        else
          name
        end
      else
        Ktistec::WebFinger.query("acct:#{name.lchop('@')}").link("self").href.presence.not_nil!
      end
    end
  end
end

require "./web_finger/client"
require "./web_finger/result"
