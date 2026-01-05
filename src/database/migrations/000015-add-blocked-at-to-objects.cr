require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "objects", "blocked_at", "datetime"
end

down do
  remove_column "objects", "blocked_at"
end
