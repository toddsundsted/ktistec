require "../framework/model"
require "../framework/model/common"
require "./activity_pub/object"

# Cached translation.
#
class Translation
  include Ktistec::Model
  include Ktistec::Model::Common

  @@table_name = "translations"

  @[Persistent]
  property origin_id : Int64?
  belongs_to origin, class_name: ActivityPub::Object, inverse_of: translations
  validates(origin) { "missing: #{origin_id}" unless origin? }

  @[Persistent]
  property name : String?

  @[Persistent]
  property summary : String?

  @[Persistent]
  property content : String?
end
