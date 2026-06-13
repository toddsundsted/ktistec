require "../view"

module Rules
  abstract class View
    # The follow notification view.
    #
    # There is one row per follow activity that targets the actor,
    # appended at the activity's arrival and never repositioned.
    #
    class Follow < View
      include NotifiesNotifications

      TYPE   = "Relationship::Content::Notification::Follow"
      FOLLOW = "ActivityPub::Activity::Follow"
      INBOX  = "Relationship::Content::Inbox"

      class_getter instance : Follow { new }

      def type : String
        TYPE
      end

      def membership(key : Key? = nil) : {String, Array(DB::Any)}
        if key
          scope = "AND a.iri = ?"
          args = Array(DB::Any){key[:to_iri]}
        else
          scope = ""
          args = Array(DB::Any).new
        end
        sql = <<-SQL
          SELECT a.object_iri AS from_iri,
                        a.iri AS to_iri,
                 a.created_at AS position
            FROM activities a
            JOIN accounts c ON c.iri = a.object_iri
           WHERE a.type = '#{FOLLOW}'
             AND a.undone_at IS NULL
             AND EXISTS (
               SELECT 1 FROM relationships m
                WHERE m.to_iri = a.iri
                  AND m.from_iri = a.object_iri
                  AND m.type = '#{INBOX}'
             )
             #{scope}
        SQL
        {sql, args}
      end

      def project(object_iri : String) : Array(Key)
        rows = Ktistec.database.query_all(<<-SQL, object_iri, as: {String, String})
          SELECT a.object_iri, a.iri
            FROM activities a
            JOIN accounts c ON c.iri = a.object_iri
           WHERE a.type = '#{FOLLOW}'
             AND a.object_iri = ?
          SQL
        rows.map { |(actor, activity)| {from_iri: actor, to_iri: activity} }
      end
    end

    register(Follow.instance)
  end
end
