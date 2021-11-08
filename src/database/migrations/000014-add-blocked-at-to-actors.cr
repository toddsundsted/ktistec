require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "actors", "blocked_at", "datetime"
end

down do |db|
  remove_column "actors", "blocked_at"
end
