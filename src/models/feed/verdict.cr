require "../../framework/model"
require "../../framework/model/common"
require "./version"

class Feed
  # A judge's verdict on one object, for one version.
  #
  class Verdict
    include Ktistec::Model
    include Ktistec::Model::Common

    @@table_name = "feed_verdicts"

    @[Persistent]
    property version_id : Int64?
    belongs_to version, class_name: Feed::Version, foreign_key: version_id, primary_key: id
    validates(version) { "missing: #{version_id}" unless version? }

    @[Persistent]
    property object_iri : String?
    belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri
    validates(object) { "missing: #{object_iri}" unless object? }

    @[Persistent]
    property included : Bool

    @[Persistent]
    property reason : String?

    TRANSIENT = "transient"
    PERMANENT = "permanent"

    @[Persistent]
    property failure : String?
    validates(failure) do
      if (failure = self.failure)
        if !failure.in?(TRANSIENT, PERMANENT)
          "is not a failure: #{failure}"
        elsif included
          "can't be included"
        end
      end
    end

    def excluded? : Bool
      !included && !failed?
    end

    def failed? : Bool
      !failure.nil?
    end
  end
end
