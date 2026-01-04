require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "actors", "down_at", "datetime"
end

down do
  remove_column "actors", "down_at"
end
