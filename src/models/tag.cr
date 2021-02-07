require "../framework/model"
require "../framework/model/**"

# Tag.
#
class Tag
  include Ktistec::Model(Common, Polymorphic)

  @@table_name = "tags"

  @[Persistent]
  property subject_iri : String { "" }
  validates(subject_iri) { absolute_uri?(subject_iri) }

  private def absolute_uri?(iri)
    if iri.blank?
      "must be present"
    elsif !URI.parse(iri).absolute?
      "must be an absolute URI: #{iri}"
    end
  end

  @[Persistent]
  property name : String

  @[Persistent]
  property href : String?
end
