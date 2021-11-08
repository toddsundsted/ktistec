require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "objects", "blocked_at", "datetime"
end

down do |db|
  remove_column "objects", "blocked_at"
end
