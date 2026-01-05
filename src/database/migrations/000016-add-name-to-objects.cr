require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "objects", "name", "text"
end

down do
  remove_column "objects", "name"
end
