require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "objects", "sensitive", "boolean DEFAULT 0"
end

down do
  remove_column "objects", "sensitive"
end
