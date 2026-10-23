require "../../framework/model"
require "../../framework/model/common"
require "./version"

class Feed
  # A question waiting to be put to a judge.
  #
  class Question
    include Ktistec::Model
    include Ktistec::Model::Common

    @@table_name = "feed_questions"

    @[Persistent]
    property version_id : Int64?
    belongs_to version, class_name: Feed::Version, foreign_key: version_id, primary_key: id

    @[Persistent]
    property object_iri : String?
    belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri

    # Whether the question is live or backfill.
    #
    @[Persistent]
    property live : Bool = false

    # When the question is due and may be pulled into a batch.
    #
    @[Persistent]
    property due_at : Time { Time.utc }

    # Whether the question is in a pulled batch.
    #
    @[Persistent]
    property batched : Bool = false

    private DUE   = "batched = 0 AND due_at <= ?"
    private ORDER = "ORDER BY live DESC, due_at ASC, id ASC"

    # Returns the version of the next question to pull, or `nil` if
    # no question is due.
    #
    def self.next_version_id(now : Time = Time.utc, excluding : Array(String) = [] of String) : Int64?
      backends = Array.new(excluding.size, "?").join(", ")
      args = [now] of DB::Any
      args.concat(excluding)
      query_all(<<-SQL, args: args).first?.try(&.version_id)
        SELECT #{columns}
          FROM #{table}
         WHERE #{DUE}
           AND version_id NOT IN (SELECT id FROM feed_versions WHERE backend IN (#{backends}))
         #{ORDER}
         LIMIT 1
        SQL
    end

    private PULL = <<-SQL
      UPDATE feed_questions
         SET batched = 1, updated_at = ?
       WHERE id IN (
         SELECT id
           FROM feed_questions
          WHERE #{DUE}
            AND version_id = ?
          #{ORDER}
          LIMIT ?
       )
      RETURNING #{columns}
      SQL

    # Pulls the next `limit` questions on a version into a batch, and
    # returns the batch.
    #
    def self.pull(version_id : Int64, limit : Int32, now : Time = Time.utc) : Array(self)
      query_all(PULL, now, now, version_id, limit)
    end
  end
end
