require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "accounts", "pinned_collections", "TEXT"
end

down do
  remove_column "accounts", "pinned_collections"
end
