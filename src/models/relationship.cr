require "../framework/model"
require "../framework/model/**"

# Relationship between things.
#
class Relationship
  include Ktistec::Model
  include Ktistec::Model::Common
  include Ktistec::Model::Polymorphic

  @@table_name = "relationships"

  @[Persistent]
  property from_iri : String

  @[Persistent]
  property to_iri : String

  @[Persistent]
  property confirmed : Bool { false }

  @[Persistent]
  property visible : Bool { false }

  @@must_be_unique = true

  def validate_model
    if @@must_be_unique
      relationship = Relationship.find?(from_iri: from_iri, to_iri: to_iri, type: type)
      if relationship && relationship.id != self.id
        errors["relationship"] = ["already exists"]
      end
    end
  end
end
