require "json"

require "../../framework/database"

extend Ktistec::Database::Migration

private def slugs_by_owner(db)
  query = "SELECT id, owner_iri, slug FROM feeds WHERE slug IS NOT NULL ORDER BY id"
  db.query_all(query, as: {Int64, String, String})
end

private def rewrite_pinned_feed_paths(db, &)
  query = "SELECT id, username, iri, pinned_collections FROM accounts WHERE pinned_collections IS NOT NULL"
  db.query_all(query, as: {Int64, String, String, String}).each do |id, username, iri, json|
    collections = Hash(String, String).from_json(json)
    pattern = Regex.new("\\A/actors/#{Regex.escape(username)}/feeds/([^/]+)\\z")
    changed = false
    collections.transform_values! do |path|
      if (match = path.match(pattern)) && (segment = yield iri, URI.decode(match[1]))
        changed = true
        "/actors/#{username}/feeds/#{URI.encode_path_segment(segment)}"
      else
        path
      end
    end
    if changed
      db.exec("UPDATE accounts SET pinned_collections = ? WHERE id = ?", collections.to_json, id)
    end
  end
end

up do |db|
  add_column "feeds", "slug", "varchar(255)"

  db.exec "CREATE INDEX idx_feeds_owner_iri_slug ON feeds (owner_iri ASC, slug ASC)"
  db.exec "UPDATE feeds SET slug = 'feed-' || id WHERE draft = 0"

  slugs = Hash(String, String).new
  slugs_by_owner(db).each do |id, _, slug|
    slugs[id.to_s] = slug
  end

  rewrite_pinned_feed_paths(db) { |_, segment| slugs[segment]? }
end

down do |db|
  ids = Hash({String, String}, String).new
  slugs_by_owner(db).each do |id, owner_iri, slug|
    ids[{owner_iri, slug}] = id.to_s
  end

  rewrite_pinned_feed_paths(db) { |owner_iri, segment| ids[{owner_iri, segment}]? }

  remove_column "feeds", "slug"
end
