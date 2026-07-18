require "../../framework/database"

extend Ktistec::Database::Migration

up do
  remove_column "feeds", "version"
  remove_column "feed_verdicts", "version"
end

down do
  add_column "feed_verdicts", "version", "integer NOT NULL DEFAULT 1"
  add_column "feeds", "version", "integer NOT NULL DEFAULT 1"
end
