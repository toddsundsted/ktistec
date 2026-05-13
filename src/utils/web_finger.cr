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
  end
end

require "./web_finger/client"
require "./web_finger/result"
