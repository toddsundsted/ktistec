require "../activity"
require "../actor"
require "./accept"
require "./reject"

class ActivityPub::Activity
  class Follow < ActivityPub::Activity
    # see: Activity.recursive
    def self.recursive
      false
    end

    belongs_to object, class_name: ActivityPub::Actor, foreign_key: object_iri, primary_key: iri

    private QUERY = "object_iri = ? AND type IN ('#{Accept}', '#{Reject}') ORDER BY id DESC LIMIT 1"

    def accepted_or_rejected?
      ActivityPub::Activity.where(QUERY, iri).first?
    end

    def valid_for_send?
      valid?
      messages = [] of String
      messages << "actor must be local" unless actor?.try(&.local?)
      messages << "object must have an inbox" unless object?.try(&.inbox)
      unless messages.empty?
        errors["activity"] = errors.fetch("activity", [] of String) + messages
      end
      errors.empty?
    end
  end
end
