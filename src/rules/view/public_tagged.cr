# require `public_timeline` first so that `PublicTimeline` registers
# before `PublicTagged`. `PublicTagged.membership` reads
# `PublicTimeline` rows, so within one `reconcile_object` pass
# `PublicTimeline` must reconcile first.
require "./public_timeline"

require "../view"

module Rules
  abstract class View
    # The public hashtag feed view.
    #
    # Membership inherits `PublicTimeline`'s semantics.
    #
    class PublicTagged < View
      TYPE            = "Relationship::Content::PublicTagged"
      PUBLIC_TIMELINE = "Relationship::Content::PublicTimeline"
      HASHTAG         = "Tag::Hashtag"

      # the instance host, read straight from settings storage.

      HOST     = "(SELECT value FROM options WHERE key = 'host')"
      FROM_IRI = "(#{HOST} || '/tags/' || lower(t.name))"

      class_getter instance : PublicTagged { new }

      def type : String
        TYPE
      end

      def membership(key : Key? = nil) : {String, Array(DB::Any)}
        if key
          scope = "AND pt.to_iri = ? AND #{FROM_IRI} = ?"
          args = Array(DB::Any){key[:to_iri], key[:from_iri]}
        else
          scope = ""
          args = Array(DB::Any).new
        end
        sql = <<-SQL
          SELECT DISTINCT
              #{FROM_IRI} AS from_iri,
                pt.to_iri AS to_iri,
            pt.created_at AS position
            FROM relationships pt
            JOIN tags t ON t.subject_iri = pt.to_iri AND t.type = '#{HASHTAG}'
           WHERE pt.type = '#{PUBLIC_TIMELINE}'
             #{scope}
        SQL
        {sql, args}
      end

      def project(object_iri : String) : Array(Key)
        # the union of (a) keys for the object's current hashtags and
        # (b) keys for its currently-stored rows, so a removed tag's
        # stale row is re-evaluated (and deleted) rather than orphaned.
        from_iris = Ktistec.database.query_all(<<-SQL, object_iri, object_iri, as: String)
          SELECT DISTINCT (#{HOST} || '/tags/' || lower(name)) AS from_iri
            FROM tags
           WHERE type = '#{HASHTAG}' AND subject_iri = ?
           UNION
          SELECT DISTINCT from_iri
            FROM relationships
           WHERE type = '#{TYPE}' AND to_iri = ?
          SQL
        from_iris.map { |from_iri| {from_iri: from_iri, to_iri: object_iri} }
      end
    end

    register(PublicTagged.instance)
  end
end
