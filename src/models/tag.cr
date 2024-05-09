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

  # Matches on tag prefix.
  #
  # Returns results ordered by number of occurrences.
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
           AND name LIKE ?
      ORDER BY count DESC
         LIMIT ?
    QUERY
    Ktistec.database.query_all(
      query,
      short_type,
      prefix + "%",
      limit,
      as: {String, Int64}
    )
  end

  # Updates tag statistics.
  #
  private def recount
    query = <<-QUERY
      INSERT OR REPLACE INTO tag_statistics (type, name, count)
      VALUES (?, ?, (
        SELECT count(*)
          FROM tags
         WHERE type = ?
           AND name = ?
        )
      )
    QUERY
    Ktistec.database.exec(
      query,
      short_type,
      name,
      type,
      name
    )
  end

  def after_save
    recount
  end

  def after_destroy
    recount
  end

  @[Persistent]
  property name : String

  @[Persistent]
  property href : String?
end
