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

    private PULL = <<-SQL
      UPDATE feed_questions
         SET batched = 1, updated_at = ?
       WHERE id = (
         SELECT id
           FROM feed_questions
          WHERE batched = 0
            AND due_at <= ?
          ORDER BY live DESC, due_at ASC, id ASC
          LIMIT 1
       )
      RETURNING #{columns}
      SQL

    # Pulls the next question that is due into a batch and returns it.
    #
    # Live before backfill, now before later -- ties broken by `id`.
    #
    def self.pull(now : Time = Time.utc) : self?
      query_all(PULL, now, now).first?
    end
  end
end
