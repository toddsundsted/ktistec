require "../../relationship"

class Relationship
  class Social
    class Follow < Relationship
      validates(from_iri) { "missing actor: from #{from_iri}" unless ActivityPub::Actor.find?(from_iri) }
      validates(to_iri) { "missing actor: to #{to_iri}" unless ActivityPub::Actor.find?(to_iri) }
    end
  end
end
