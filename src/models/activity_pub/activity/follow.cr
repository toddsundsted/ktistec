require "../activity"
require "../actor"
require "./accept"
require "./reject"

class ActivityPub::Activity
  class Follow < ActivityPub::Activity
    @@recursive = false

    belongs_to object, class_name: ActivityPub::Actor, foreign_key: object_iri, primary_key: iri

    def self.follows?(actor_or_iri, object_or_iri)
      actor_iri = actor_or_iri.is_a?(ActivityPub::Actor) ?
        actor_or_iri.iri :
        actor_or_iri
      object_iri = object_or_iri.is_a?(ActivityPub::Actor) ?
        object_or_iri.iri :
        object_or_iri

      {% begin %}
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        columns = {{vs.map { |v| "f.#{v.stringify}" }.join(",")}}
        query = <<-SQL
            SELECT #{columns}
              FROM #{table} f
              JOIN relationships r
                ON r.from_iri = f.actor_iri
               AND r.to_iri = f.object_iri
             WHERE f.type = '#{ActivityPub::Activity::Follow}'
               AND r.type = '#{Relationship::Social::Follow}'
               AND actor_iri = ?
               AND object_iri = ?
          ORDER BY f.created_at desc
             LIMIT 1
        SQL
        query_one(query, actor_iri, object_iri)
      {% end %}
    rescue DB::NoResultsError
    end

    private QUERY = "object_iri = ? AND type IN ('#{Accept}', '#{Reject}') LIMIT 1"

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
