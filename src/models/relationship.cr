require "../framework/model"

# Relationship between things.
#
class Relationship
  include Ktistec::Model(Common, Polymorphic)

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

  def validate(**options)
    super
    if @@must_be_unique
      relationship = Relationship.find?(from_iri: from_iri, to_iri: to_iri, type: type)
      if relationship && relationship.id != self.id
        errors["relationship"] = ["already exists"]
      end
    end
    errors
  end
end
