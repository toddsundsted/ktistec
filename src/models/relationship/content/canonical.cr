require "../../relationship"
require "../../activity_pub/object"

class Relationship
  class Content
    class Canonical < Relationship
      validates(from_iri) do
        return "must be absolute" unless from_iri.starts_with?('/')
        return "must not match an existing route" if Kemal::RouteHandler::INSTANCE.lookup_route("GET", from_iri).found?
        return "must be unique" if (instance = self.class.find?(from_iri: from_iri)) && instance.id != self.id
      end

      validates(to_iri) do
        return "must be absolute" unless to_iri.starts_with?('/')
        return "must match an existing route" unless Kemal::RouteHandler::INSTANCE.lookup_route("GET", to_iri).found?
        return "must be unique" if (instance = self.class.find?(to_iri: to_iri)) && instance.id != self.id
      end
    end
  end
end
