require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "actors", "blocked_at", "datetime"
end

down do
  remove_column "actors", "blocked_at"
end
