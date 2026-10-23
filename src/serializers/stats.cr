require "../framework/database"

module Serializers
  # A stats view-object.
  #
  struct Stats
    # The quartiles of a set of values.
    #
    record Quartiles, q1 : Float64?, median : Float64?, q3 : Float64? do
      # Computes the quartiles of `values`.
      #
      # Interpolates linearly between values. Given no values, there
      # are no quartiles.
      #
      def self.from(values : Enumerable(Float64)) : Quartiles
        sorted = values.sort
        new(
          q1: quantile(sorted, 0.25),
          median: quantile(sorted, 0.5),
          q3: quantile(sorted, 0.75),
        )
      end

      private def self.quantile(sorted : Array(Float64), p : Float64) : Float64?
        unless sorted.empty?
          position = (sorted.size - 1) * p
          lower = position.floor.to_i
          upper = position.ceil.to_i
          sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower)
        end
      end
    end

    # The posting rates of the authors the owner follows, in posts per
    # day.
    #
    getter posting_rate : Quartiles

    def initialize(@posting_rate : Quartiles)
    end

    # Computes the stats for `owner_iri` as of `now`.
    #
    def self.from(owner_iri : String?, now : Time) : Stats
      new(posting_rate: posting_rate(owner_iri, now))
    end

    private POSTING_RATE_WINDOW = 90

    private POSTING_RATES = <<-SQL
      SELECT (SELECT count(*)
                FROM objects o
               WHERE o.attributed_to_iri = r.to_iri
                 AND o.published > ?
                 AND o.special IS NULL
                 AND o.deleted_at IS NULL
                 AND o.blocked_at IS NULL) / #{POSTING_RATE_WINDOW}.0
        FROM relationships r
        JOIN actors a
          ON a.iri = r.to_iri
       WHERE r.type = 'Relationship::Social::Follow'
         AND r.from_iri = ?
         AND r.confirmed = 1
         AND a.deleted_at IS NULL
         AND a.blocked_at IS NULL
      SQL

    # Computes the posting rates of the authors `owner_iri` follows,
    # over the window ending at `now`.
    #
    # Authors who haven't posted in the window are ignored.
    #
    private def self.posting_rate(owner_iri : String?, now : Time) : Quartiles
      rates = Ktistec.database.query_all(POSTING_RATES, now - POSTING_RATE_WINDOW.days, owner_iri, as: Float64)
      Quartiles.from(rates.select(&.> 0))
    end
  end
end
