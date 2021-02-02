require "../framework/model"
require "../framework/model/**"

# Tag.
#
class Tag
  include Ktistec::Model(Common, Polymorphic)

  @@table_name = "tags"

  @[Persistent]
  property subject_iri : String

  @[Persistent]
  property name : String

  @[Persistent]
  property href : String?
end
