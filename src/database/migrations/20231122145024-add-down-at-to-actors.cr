require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "actors", "down_at", "datetime"
end

down do |db|
  remove_column "actors", "down_at"
end
