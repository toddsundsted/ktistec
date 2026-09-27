require "json"

require "../../framework/database"

extend Ktistec::Database::Migration

# `judging_params` and `canonicalize` are a snapshot of how
# `Feed::Version.for` keys a criteria feed, reproduced here to avoid a
# dependency on models during migration.

private def judging_params(params)
  params.reject("order").transform_values do |selectors|
    next selectors unless (raw = selectors.as_h?)
    JSON::Any.new(raw.transform_values do |list|
      next list unless (terms = list.as_a?)
      JSON::Any.new(terms.sort_by { |term| term.as_s? || "" })
    end)
  end
end

private def canonicalize(value : JSON::Any) : JSON::Any
  if (hash = value.as_h?)
    JSON::Any.new(hash.to_a.sort_by!(&.[0]).to_h.transform_values { |element| canonicalize(element) })
  else
    value
  end
end

up do |db|
  db.exec <<-STR
    CREATE TABLE feed_versions (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "backend" varchar(63) NOT NULL,
      "params" text NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_feed_versions_backend_params
      ON feed_versions (backend ASC, params ASC)
  STR
  add_column "feeds", "version_id", "integer", index: "ASC"
  db.query_all("SELECT id, backend, params FROM feeds", as: {Int64, String, String?}).each do |id, backend, params|
    stored = Hash(String, JSON::Any).from_json(params || "{}")
    key = canonicalize(JSON::Any.new(judging_params(stored))).to_json
    db.exec(<<-STR, backend, key)
      INSERT OR IGNORE INTO feed_versions (created_at, updated_at, backend, params)
      VALUES (datetime('now'), datetime('now'), ?, ?)
    STR
    db.exec(<<-STR, backend, key, id)
      UPDATE feeds
         SET version_id = (SELECT id FROM feed_versions WHERE backend = ? AND params = ?)
       WHERE id = ?
    STR
  end
end

down do |db|
  remove_column "feeds", "version_id"
  db.exec <<-STR
    DROP TABLE feed_versions
  STR
end
