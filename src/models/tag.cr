require "../framework/model"
require "../framework/model/**"

# Tag.
#
class Tag
  include Ktistec::Model(Common, Polymorphic)

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

  macro inherited
    def self.short_type
      self.to_s.split("::").last.underscore
    end

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
  end

  def short_type
    self.class.to_s.split("::").last.underscore
  end

  def count
    query = <<-QUERY
      SELECT ifnull(sum(count), 0) FROM tag_statistics WHERE type = ? AND name = ?
    QUERY
    Ktistec.database.scalar(
      query,
      self.short_type,
      self.name
    )
  end

  private def recount
    query = <<-QUERY
      INSERT OR REPLACE INTO tag_statistics (type, name, count)
      VALUES (?, ?, (
        SELECT count(*) FROM tags WHERE type = ? AND name = ?)
      )
    QUERY
    Ktistec.database.exec(
      query,
      self.short_type,
      self.name,
      self.type,
      self.name
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
