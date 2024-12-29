module Ktistec
  module Constants
    PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

    ACCEPT_HEADER = %q|application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams"|

    CONTENT_TYPE_HEADER = %q|application/ld+json; profile="https://www.w3.org/ns/activitystreams"|

    LANGUAGE_RE = /^[a-zA-Z]{2,3}(-[a-zA-Z0-9]+)*$/
  end
end
