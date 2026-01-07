require "../framework/model"
require "../framework/model/**"

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

  # Matches on tag prefix.
  #
  # Returns results ordered by number of occurrences. Treats SQL LIKE
  # wildcards (% and _) as literal characters.
  #
  # Count is intentionally not adjusted for subjects that are deleted,
  # blocked, etc. making the value unsuitable for presentation, in
  # most cases.
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

  # Updates tag statistics by recounting all posts with a tag.
  #
  private def full_recount
    query = <<-QUERY
      INSERT OR REPLACE INTO tag_statistics (type, name, count)
      VALUES (?, ?, (
        SELECT count(*)
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

  # Updates tag statistics by applying a difference to the count.
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

  # handle two use cases: 1) rapidly fetching posts, 2) tags that are
  # expensive to fully count. currently, do a full count only after a
  # server restart. things (e.g. blocking/deleting actors) can affect
  # the full count in the meantime, but hopefully the impact is not
  # noticeable.

  record CacheEntry, type : String, name : String

  class_property cache = Set(CacheEntry).new

  def after_create
    entry = CacheEntry.new(short_type, name.downcase)
    if Tag.cache.includes?(entry)
      increment_count
    else
      Tag.cache.add(entry)
      full_recount
    end
  end

  def after_destroy
    entry = CacheEntry.new(short_type, name.downcase)
    if Tag.cache.includes?(entry)
      decrement_count
    else
      Tag.cache.add(entry)
      full_recount
    end
  end

  @[Persistent]
  property name : String

  @[Persistent]
  property href : String?
end
