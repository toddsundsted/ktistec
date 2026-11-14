require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "accounts", "timeline_feed", "TEXT"
end

down do
  remove_column "accounts", "timeline_feed"
end
