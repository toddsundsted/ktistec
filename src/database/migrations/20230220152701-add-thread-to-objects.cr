require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "objects", "thread", "text COLLATE NOCASE", index: "ASC"
end

down do
  remove_column "objects", "thread"
end
