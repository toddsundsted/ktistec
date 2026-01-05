require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "objects", "special", "text"
end

down do
  remove_column "objects", "special"
end
