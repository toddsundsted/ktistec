require "json"
require "uri"

require "../../framework/database"
require "../../framework/util"

extend Ktistec::Database::Migration

# Sweep existing ActivityPub records for IRI/URL fields that
# would be rejected by the model-layer validators added after
# the records themselves. Three rejection axes:
#
# - Disallowed schemes -- javascript:, data:, vbscript:, file:,
#   etc. (and control-character-obfuscated variants like
#   `java\nscript:` that the WHATWG URL parser would normalize).
# - Unsafe characters -- C0 controls (U+0000-U+001F), DEL
#   (U+007F), and ASCII space anywhere in the value; identifier
#   IRIs additionally reject `"`, `'`, `\`, `<`, `>`.
# - Non-absolute URIs (identifier IRIs only) -- the value must
#   parse as having a scheme.
#
# Two predicates with different strictness, mirroring the runtime
# model layer:
#
# - `unsafe_iri?` mirrors `Ktistec::Model::Linked#unique_absolute_uri?`:
#   the value must be an absolute URI (`Ktistec::Util.absolute_uri?`)
#   AND must pass `safe_iri?` (http/https only, plus the wider
#   character pre-filter rejecting `"`, `'`, `\`, `<`, `>`).
#   Applied to identifier `iri` columns on every record.
#
# - `unsafe_url?` mirrors the model-layer display-URL scrubs
#   (`Ktistec::Util.safe_url?`): wider scheme allowlist (the F5
#   v2 production-traffic set: http, https, mailto, tel, xmpp,
#   matrix, magnet, ws, wss, at, did) and the narrower C0/space
#   pre-filter. Applied to display URL fields (icon, image, urls,
#   attachment URLs, tag href).

module ScrubUnsafeUrls
  extend self

  Log = ::Log.for(self)

  BATCH_SIZE = 1000

  def unsafe_url?(value) : Bool
    value.is_a?(String) && !value.empty? && !Ktistec::Util.safe_url?(value)
  end

  def unsafe_iri?(value) : Bool
    value.is_a?(String) && !value.empty? &&
      (!Ktistec::Util.absolute_uri?(value) || !Ktistec::Util.safe_iri?(value))
  end

  # Filters unsafe entries from a JSON array of URL strings.
  #
  def filter_url_array(json : String?) : {String?, Int32}
    return {json, 0} if json.nil?
    urls = Array(String).from_json(json) rescue nil
    return {json, 0} if urls.nil?
    safe = urls.reject { |u| unsafe_url?(u) }
    dropped = urls.size - safe.size
    return {json, 0} if dropped == 0
    {safe.to_json, dropped}
  end

  # Filters unsafe entries from a JSON array of attachment hashes.
  #
  def filter_attachments(json : String?, url_field : String) : {String?, Int32}
    return {json, 0} if json.nil?
    attachments = Array(JSON::Any).from_json(json) rescue nil
    return {json, 0} if attachments.nil?
    safe = attachments.reject do |att|
      h = att.as_h?
      next false if h.nil?
      v = h[url_field]?.try(&.as_s?)
      unsafe_url?(v)
    end
    dropped = attachments.size - safe.size
    return {json, 0} if dropped == 0
    {safe.to_json, dropped}
  end

  def run(db)
    Log.info { "Sweep: scanning records..." }
    sweep_actors(db)
    sweep_objects(db)
    sweep_simple(db, "activities", "activity")
    sweep_simple(db, "collections", "collection")
    sweep_tags(db)
    Log.info { "Sweep: complete." }
  end

  def sweep_actors(db)
    count = db.scalar(%q|SELECT COUNT(*) FROM "actors" WHERE "deleted_at" IS NULL|).as(Int64)
    Log.info { "Sweep: actors (#{count} rows)..." }

    last_id = 0_i64
    soft_deleted = 0
    scrubbed = 0
    details = [] of String

    loop do
      rows = [] of {Int64, String, String?, String?, String?}
      db.query(<<-SQL, last_id, BATCH_SIZE) do |rs|
        SELECT "id", "iri", "icon", "image", "urls"
          FROM "actors"
         WHERE "id" > ? AND "deleted_at" IS NULL
      ORDER BY "id"
         LIMIT ?
      SQL
        rs.each do
          rows << {
            rs.read(Int64),
            rs.read(String),
            rs.read(String?),
            rs.read(String?),
            rs.read(String?),
          }
        end
      end
      break if rows.empty?

      rows.each do |id, iri, icon, image, urls_json|
        if unsafe_iri?(iri)
          db.exec(
            %q|UPDATE "actors" SET "deleted_at" = ? WHERE "id" = ?|,
            Time.utc, id,
          )
          soft_deleted += 1
          details << "actor id=#{id} soft-deleted (unsafe iri: #{iri.inspect})"
          next
        end

        new_icon = (icon && unsafe_url?(icon)) ? nil : icon
        new_image = (image && unsafe_url?(image)) ? nil : image
        new_urls_json, urls_dropped = filter_url_array(urls_json)

        changed = (new_icon != icon) || (new_image != image) || (new_urls_json != urls_json)

        if changed
          db.exec(<<-SQL, new_icon, new_image, new_urls_json, id)
            UPDATE "actors"
               SET "icon" = ?, "image" = ?, "urls" = ?
             WHERE "id" = ?
          SQL
          scrubbed += 1
          notes = [] of String
          notes << "icon nulled" if new_icon != icon
          notes << "image nulled" if new_image != image
          notes << "#{urls_dropped} url(s) dropped" if urls_dropped > 0
          details << "actor id=#{id} #{notes.join(", ")}"
        end
      end

      last_id = rows.last[0]
    end

    Log.info { "  actors: done. #{soft_deleted} soft-deleted, #{scrubbed} with display URLs scrubbed." }
    details.each { |d| Log.info { "  - #{d}" } }
  end

  def sweep_objects(db)
    count = db.scalar(%q|SELECT COUNT(*) FROM "objects" WHERE "deleted_at" IS NULL|).as(Int64)
    Log.info { "Sweep: objects (#{count} rows)..." }

    last_id = 0_i64
    soft_deleted = 0
    scrubbed = 0
    details = [] of String

    loop do
      rows = [] of {Int64, String, String?, String?}
      db.query(<<-SQL, last_id, BATCH_SIZE) do |rs|
        SELECT "id", "iri", "urls", "attachments"
          FROM "objects"
         WHERE "id" > ? AND "deleted_at" IS NULL
      ORDER BY "id"
         LIMIT ?
      SQL
        rs.each do
          rows << {
            rs.read(Int64),
            rs.read(String),
            rs.read(String?),
            rs.read(String?),
          }
        end
      end
      break if rows.empty?

      rows.each do |id, iri, urls_json, attachments_json|
        if unsafe_iri?(iri)
          db.exec(
            %q|UPDATE "objects" SET "deleted_at" = ? WHERE "id" = ?|,
            Time.utc, id,
          )
          soft_deleted += 1
          details << "object id=#{id} soft-deleted (unsafe iri: #{iri.inspect})"
          next
        end

        new_urls_json, urls_dropped = filter_url_array(urls_json)
        new_attachments_json, attachments_dropped = filter_attachments(attachments_json, "url")

        changed = (new_urls_json != urls_json) || (new_attachments_json != attachments_json)

        if changed
          db.exec(<<-SQL, new_urls_json, new_attachments_json, id)
            UPDATE "objects"
               SET "urls" = ?, "attachments" = ?
             WHERE "id" = ?
          SQL
          scrubbed += 1
          notes = [] of String
          notes << "#{urls_dropped} url(s) dropped" if urls_dropped > 0
          notes << "#{attachments_dropped} attachment(s) dropped" if attachments_dropped > 0
          details << "object id=#{id} #{notes.join(", ")}"
        end
      end

      last_id = rows.last[0]
    end

    Log.info { "  objects: done. #{soft_deleted} soft-deleted, #{scrubbed} with display URLs scrubbed." }
    details.each { |d| Log.info { "  - #{d}" } }
  end

  def sweep_simple(db, table : String, singular : String)
    count = db.scalar(%Q|SELECT COUNT(*) FROM "#{table}"|).as(Int64)
    Log.info { "Sweep: #{table} (#{count} rows)..." }

    last_id = 0_i64
    hard_deleted = 0
    details = [] of String

    loop do
      rows = [] of {Int64, String}
      db.query(<<-SQL, last_id, BATCH_SIZE) do |rs|
        SELECT "id", "iri" FROM "#{table}" WHERE "id" > ? ORDER BY "id" LIMIT ?
      SQL
        rs.each do
          rows << {rs.read(Int64), rs.read(String)}
        end
      end
      break if rows.empty?

      rows.each do |id, iri|
        if unsafe_iri?(iri)
          db.exec(%Q|DELETE FROM "#{table}" WHERE "id" = ?|, id)
          hard_deleted += 1
          details << "#{singular} id=#{id} hard-deleted (unsafe iri: #{iri.inspect})"
        end
      end

      last_id = rows.last[0]
    end

    Log.info { "  #{table}: done. #{hard_deleted} hard-deleted." }
    details.each { |d| Log.info { "  - #{d}" } }
  end

  # `Tag::Mention.href` and `Tag::Hashtag.href` arrive raw from
  # federated JSON-LD with no scheme check upstream. Mirror the
  # model-layer scrub: nil out unsafe href on Mention/Hashtag (those
  # subclasses allow nil; render path uses mention_path/hashtag_path
  # keyed on `name`). Drop the row entirely for Tag::Emoji -- the
  # subclass's `validates(href)` requires presence and
  # `Ktistec::Emoji.emojify` calls `href.not_nil!`, so a nil-href
  # emoji is malformed.
  def sweep_tags(db)
    count = db.scalar(%q|SELECT COUNT(*) FROM "tags"|).as(Int64)
    Log.info { "Sweep: tags (#{count} rows)..." }

    last_id = 0_i64
    scrubbed = 0
    emojis_deleted = 0
    details = [] of String

    loop do
      rows = [] of {Int64, String, String?}
      db.query(<<-SQL, last_id, BATCH_SIZE) do |rs|
        SELECT "id", "type", "href"
          FROM "tags"
         WHERE "id" > ?
      ORDER BY "id"
         LIMIT ?
      SQL
        rs.each do
          rows << {rs.read(Int64), rs.read(String), rs.read(String?)}
        end
      end
      break if rows.empty?

      rows.each do |id, type, href|
        next unless unsafe_url?(href)

        case type
        when "Tag::Mention", "Tag::Hashtag"
          db.exec(%q|UPDATE "tags" SET "href" = NULL WHERE "id" = ?|, id)
          scrubbed += 1
          details << "tag id=#{id} #{type} href nulled (unsafe href: #{href.inspect})"
        when "Tag::Emoji"
          db.exec(%q|DELETE FROM "tags" WHERE "id" = ?|, id)
          emojis_deleted += 1
          details << "tag id=#{id} Tag::Emoji deleted (unsafe href: #{href.inspect})"
        end
      end

      last_id = rows.last[0]
    end

    Log.info { "  tags: done. #{scrubbed} mention/hashtag href(s) nulled, #{emojis_deleted} emoji(s) deleted." }
    details.each { |d| Log.info { "  - #{d}" } }
  end
end

up do |db|
  ScrubUnsafeUrls.run(db)
end

down do
end
