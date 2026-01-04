require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "objects", "updated", "datetime"
end

down do
  remove_column "objects", "updated"
end
