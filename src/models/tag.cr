require "../framework/model"
require "../framework/model/common"
require "../framework/observable"

# Tag.
#
class Tag
  include Ktistec::Model
  include Ktistec::Model::Common
  include Ktistec::Model::Polymorphic

  @@table_name = "tags"

  @[Persistent]
  property subject_iri : String { "" }
  validates(subject_iri) { absolute_uri?(subject_iri) }

  private def absolute_uri?(iri)
    if iri.blank?
      "must be present"
    elsif !URI.parse(iri).absolute?
      "must be an absolute URI: #{iri}"
    end
  end

  def self.short_type
    self.to_s.split("::").last.underscore
  end

  def short_type
    self.class.short_type
  end

  # Adds common filters to a query.
  #
  macro common_filters(**options)
    <<-FILTERS
      {% if (key = options[:objects]) %}
        AND {{key.id}}.special is NULL
        AND {{key.id}}.deleted_at is NULL
        AND {{key.id}}.blocked_at is NULL
      {% end %}
      {% if (key = options[:actors]) %}
        AND {{key.id}}.deleted_at IS NULL
        AND {{key.id}}.blocked_at IS NULL
      {% end %}
      {% if (key = options[:activities]) %}
        AND {{key.id}}.undone_at IS NULL
      {% end %}
    FILTERS
  end

  # # Tag statistics
  #
  # `tag_statistics` caches, per (type, name), how many *distinct
  # objects* carry that tag and are currently displayable. That count
  # is exactly what `all_objects_count` returns.
  #
  # Maintained at two fidelities:
  #
  # `#full_recount` and `.reconcile_statistics` recompute the
  # *precise* population.
  #
  # `#update_count` is the fast path between reconciles, so it drifts:
  # e.g. an actor blocked after tagging is not decremented.

  # Matches on tag prefix.
  #
  # Returns results ordered by number of occurrences. Treats SQL LIKE
  # wildcards (% and _) as literal characters.
  #
  # Ranks by the cached count; approximate between reconciles, which is
  # fine for ranking.
  #
  # See "Tag statistics".
  #
  def self.match(prefix, limit = 1)
    query = <<-QUERY
        SELECT name, count
          FROM tag_statistics
         WHERE type = ?
           AND name LIKE ? ESCAPE '\\'
      ORDER BY count DESC
         LIMIT ?
    QUERY
    escaped_prefix = prefix.gsub("%", "\\%").gsub("_", "\\_")
    args = {short_type, escaped_prefix + "%", limit}
    Internal.log_query(query, args) do
      Ktistec.database.query_all(
        query, *args,
        as: {String, Int64},
      )
    end
  end

  # Exact recount of one key.
  #
  # See "Tag statistics".
  #
  private def full_recount
    query = <<-QUERY
      INSERT OR REPLACE INTO tag_statistics (type, name, count)
      VALUES (?, ?, (
        SELECT count(DISTINCT t.subject_iri)
          FROM tags AS t
          JOIN objects AS o
            ON o.iri = t.subject_iri
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.type = ?
           AND t.name = ?
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "a")}
        )
      )
    QUERY
    args = {short_type, name, type, name}
    Internal.log_query(query, args) do
      Ktistec.database.exec(
        query, *args,
      )
    end
  end

  # Tag types with a count surface. Only these are cached and
  # reconciled.
  #
  # See "Tag statistics".
  #
  TRACKED_TYPES = {"Tag::Hashtag" => "hashtag", "Tag::Mention" => "mention"}

  # Exact recount of every tracked key.
  #
  # Heals `#update_count` drift and closes the missing-key gap.
  #
  # See "Tag statistics".
  #
  def self.reconcile_statistics
    full_types = TRACKED_TYPES.keys.map { |t| "'#{t}'" }.join(", ")
    short_types = TRACKED_TYPES.values.map { |t| "'#{t}'" }.join(", ")

    # phase 1: compute truth
    truth = {} of {String, String} => {String, Int64}
    truth_query = <<-QUERY
        SELECT t.type, t.name, count(DISTINCT t.subject_iri)
          FROM tags AS t
          JOIN objects AS o
            ON o.iri = t.subject_iri
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.type IN (#{full_types})
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "a")}
      GROUP BY t.type, t.name
    QUERY
    Internal.log_query(truth_query) do
      Ktistec.database.query(truth_query) do |rs|
        rs.each do
          full_type, name, count = rs.read(String, String, Int64)
          truth[{TRACKED_TYPES[full_type], name.downcase}] = {name, count}
        end
      end
    end

    # phase 2: read the cache and diff
    cache = {} of {String, String} => {String, Int64}
    cache_query = <<-QUERY
      SELECT type, name, count
        FROM tag_statistics
       WHERE type IN (#{short_types})
    QUERY
    Internal.log_query(cache_query) do
      Ktistec.database.query(cache_query) do |rs|
        rs.each do
          short_type, name, count = rs.read(String, String, Int64)
          cache[{short_type, name.downcase}] = {name, count}
        end
      end
    end

    upserts = [] of {String, String, Int64}
    zeros = [] of {String, String}
    inserted = updated = zeroed = 0
    truth.each do |key, (name, count)|
      if (existing = cache[key]?)
        next if existing[1] == count
        updated += 1
      else
        inserted += 1
      end
      upserts << {key[0], name, count}
    end
    cache.each do |key, (name, count)|
      next if truth.has_key?(key) || count == 0
      zeros << {key[0], name}
      zeroed += 1
    end

    # phase 3: apply the delta
    upsert_query = <<-QUERY
      INSERT INTO tag_statistics (type, name, count)
      VALUES (?, ?, ?)
      ON CONFLICT (type, name) DO UPDATE SET count = excluded.count
    QUERY
    upserts.each do |args|
      Internal.log_query(upsert_query, args) do
        Ktistec.database.exec(upsert_query, *args)
      end
    end
    zero_query = <<-QUERY
      UPDATE tag_statistics SET count = 0 WHERE type = ? AND name = ?
    QUERY
    zeros.each do |args|
      Internal.log_query(zero_query, args) do
        Ktistec.database.exec(zero_query, *args)
      end
    end

    {inserted: inserted, updated: updated, zeroed: zeroed}
  end

  # Approximate increment/decrement fast path.
  #
  # See "Tag statistics".
  #
  private def update_count(difference)
    query = <<-QUERY
      UPDATE tag_statistics AS ts
         SET count = count + ?
        FROM tags AS t, objects AS o, actors AS a
       WHERE ts.type = ?
         AND ts.name = ?
         AND t.id = ?
         AND o.iri = t.subject_iri
         AND a.iri = o.attributed_to_iri
         AND o.published IS NOT NULL
         #{common_filters(objects: "o", actors: "a")}
    QUERY
    args = {difference, short_type, name, id}
    Internal.log_query(query, args) do
      Ktistec.database.exec(
        query, *args,
      )
    end
  end

  private macro increment_count
    update_count(1)
  end

  private macro decrement_count
    update_count(-1)
  end

  # Returns true if a `tag_statistics` row exists for this tag.
  #
  private def statistics_row_exists?
    query = <<-QUERY
      SELECT 1
        FROM tag_statistics
       WHERE type = ?
         AND name = ?
       LIMIT 1
    QUERY
    args = {short_type, name}
    Internal.log_query(query, args) do
      !Ktistec.database.query_one?(query, *args, as: Int64).nil?
    end
  end

  # Increments (or fully recounts) tag statistics for a created tag.
  #
  protected def increment_statistics
    if statistics_row_exists?
      increment_count
    else
      full_recount
    end
  end

  # Decrements (or fully recounts) tag statistics for a destroyed tag.
  #
  protected def decrement_statistics
    if statistics_row_exists?
      decrement_count
    else
      full_recount
    end
  end

  OBSERVERS = Ktistec::Observable::Registry(Tag).new

  OBSERVERS.observe(:create, &.increment_statistics)
  OBSERVERS.observe(:destroy, &.decrement_statistics)

  def after_create
    Tag::OBSERVERS.notify(:create, self)
  end

  def after_destroy
    Tag::OBSERVERS.notify(:destroy, self)
  end

  @[Persistent]
  property name : String

  @[Persistent]
  property href : String?
end
