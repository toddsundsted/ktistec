require "../view"
require "../../models/relationship/content/notification/follow/hashtag"
require "../../models/relationship/content/follow/hashtag"
require "../../models/tag/hashtag"
require "../../models/activity_pub/object"
require "../../models/activity_pub/actor"

module Rules
  abstract class View
    # The hashtag-follow notification view.
    #
    # There is one row per hashtag the owner follows, bumped to the
    # recency of the newest qualifying object tagged with the hashtag.
    #
    class FollowHashtag < View
      include NotifiesNotifications

      TYPE    = Relationship::Content::Notification::Follow::Hashtag.to_s
      FOLLOW  = Relationship::Content::Follow::Hashtag.to_s
      HASHTAG = Tag::Hashtag.to_s

      class_getter instance : FollowHashtag { new }

      def type : String
        TYPE
      end

      def repositions? : Bool
        true
      end

      def membership(key : Key? = nil) : {String, Array(DB::Any)}
        if key
          scope = "AND f.from_iri = ? AND f.to_iri = ?"
          args = Array(DB::Any){key[:from_iri], key[:to_iri]}
        else
          scope = ""
          args = Array(DB::Any).new
        end
        sql = <<-SQL
          SELECT f.from_iri AS from_iri,
                 f.to_iri   AS to_iri,
                 MAX(o.created_at) AS position
            FROM relationships f
            JOIN accounts c ON c.iri = f.from_iri
            JOIN tags t     ON t.type = '#{HASHTAG}' AND t.name = f.to_iri
            JOIN objects o  ON o.iri = t.subject_iri
                           AND o.attributed_to_iri <> f.from_iri
            JOIN actors s   ON s.iri = o.attributed_to_iri
                           AND s.blocked_at IS NULL
           WHERE f.type = '#{FOLLOW}'
             AND o.created_at > f.created_at
             #{scope}
           GROUP BY f.from_iri, f.to_iri
        SQL
        {sql, args}
      end

      def project(object_iri : String) : Array(Key)
        rows = Ktistec.database.query_all(<<-SQL, object_iri, as: {String, String})
          SELECT f.from_iri, f.to_iri
            FROM tags t
            JOIN relationships f ON f.type = '#{FOLLOW}' AND f.to_iri = t.name
            JOIN accounts c ON c.iri = f.from_iri
           WHERE t.type = '#{HASHTAG}'
             AND t.subject_iri = ?
          SQL
        rows.map { |(owner, name)| {from_iri: owner, to_iri: name} }
      end
    end

    register(FollowHashtag.instance)
  end
end
