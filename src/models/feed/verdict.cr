require "../../framework/model"
require "../../framework/model/common"
require "../feed"

class Feed
  # A judge's verdict on one object, for one feed.
  #
  class Verdict
    include Ktistec::Model
    include Ktistec::Model::Common

    @@table_name = "feed_verdicts"

    @[Persistent]
    property feed_id : Int64?
    belongs_to feed, class_name: ::Feed, foreign_key: feed_id, primary_key: id, inverse_of: verdicts
    validates(feed) { "missing: #{feed_id}" unless feed? }

    @[Persistent]
    property object_iri : String?
    belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri
    validates(object) { "missing: #{object_iri}" unless object? }

    @[Persistent]
    property included : Bool

    @[Persistent]
    property reason : String?

    # The feed config version the verdict was judged under.
    #
    # The view treats verdicts whose version is not the feed's current
    # version as stale and excludes them.
    #
    @[Persistent]
    property version : Int32 = 1

    # The time the object arrived -- the `created_at` of the earliest
    # mailbox row that delivered it to the feed's owner.
    #
    @[Persistent]
    property position : Time
  end
end
