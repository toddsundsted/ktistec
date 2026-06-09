require "../view"
require "../../models/relationship/content/notification/follow/thread"
require "../../models/relationship/content/follow/thread"
require "../../models/activity_pub/object"
require "../../models/activity_pub/actor"

module Rules
  abstract class View
    # The thread-follow notification view.
    #
    # There is one row per followed thread, keyed on the thread root,
    # bumped to the recency of the newest qualifying object in the
    # thread.
    #
    class FollowThread < View
      TYPE   = Relationship::Content::Notification::Follow::Thread.to_s
      FOLLOW = Relationship::Content::Follow::Thread.to_s

      class_getter instance : FollowThread { new }

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
            JOIN accounts c   ON c.iri = f.from_iri
            JOIN objects root ON root.iri = f.to_iri
            JOIN objects o    ON o.thread = f.to_iri
                             AND o.attributed_to_iri <> f.from_iri
            JOIN actors s     ON s.iri = o.attributed_to_iri
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
            FROM objects o
            JOIN relationships f ON f.type = '#{FOLLOW}' AND f.to_iri = o.thread
            JOIN accounts c ON c.iri = f.from_iri
           WHERE o.iri = ?
          SQL
        rows.map { |(owner, thread)| {from_iri: owner, to_iri: thread} }
      end
    end

    register(FollowThread.instance)
  end
end
