require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "objects", "updated", "datetime"
end

down do |db|
  remove_column "objects", "updated"
end
