# [ActivityPub](https://www.w3.org/TR/activitypub/) server.
#
module Balloon
  # :nodoc:
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end
