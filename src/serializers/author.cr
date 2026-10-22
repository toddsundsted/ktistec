require "../framework/database"

module Serializers
  # An author view-object.
  #
  struct Author
    getter iri : String

    # Whether the feed's owner follows the author.
    #
    getter followed : Bool

    # The author's posting rate over the last 7 days, in posts per day.
    #
    getter rate_7 : Float64

    # The author's posting rate over the last 30 days, in posts per day.
    #
    getter rate_30 : Float64

    # The author's posting rate over the last 90 days, in posts per day.
    #
    getter rate_90 : Float64

    def initialize(@iri : String, @followed : Bool, @rate_7 : Float64, @rate_30 : Float64, @rate_90 : Float64)
    end

    private FOLLOWED = <<-SQL
      SELECT count(*)
        FROM relationships r
        JOIN actors a
          ON a.iri = r.to_iri
       WHERE r.type = 'Relationship::Social::Follow'
         AND r.from_iri = ?
         AND r.to_iri = ?
         AND r.confirmed = 1
         AND a.deleted_at IS NULL
         AND a.blocked_at IS NULL
      SQL

    private RATES = <<-SQL
      SELECT total(o.published > ?) / 7.0,
             total(o.published > ?) / 30.0,
             count(*) / 90.0
        FROM objects o
        JOIN actors a
          ON a.iri = o.attributed_to_iri
       WHERE o.attributed_to_iri = ?
         AND o.published > ?
         AND o.special IS NULL
         AND o.deleted_at IS NULL
         AND o.blocked_at IS NULL
         AND a.deleted_at IS NULL
         AND a.blocked_at IS NULL
      SQL

    # Returns an `Author` view-object.
    #
    # Facts about the author are as seen by `owner_iri`.
    #
    def self.from(iri : String, owner_iri : String?, now : Time) : Author
      followed = Ktistec.database.scalar(FOLLOWED, owner_iri, iri).as(Int64) > 0
      rate_7, rate_30, rate_90 = Ktistec.database.query_one(RATES, now - 7.days, now - 30.days, iri, now - 90.days, as: {Float64, Float64, Float64})
      new(iri: iri, followed: followed, rate_7: rate_7, rate_30: rate_30, rate_90: rate_90)
    end
  end
end
