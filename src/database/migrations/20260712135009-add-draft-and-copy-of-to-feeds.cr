require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "feeds", "draft", "boolean NOT NULL DEFAULT 0"
  add_column "feeds", "copy_of", "integer"
end

down do
  remove_column "feeds", "copy_of"
  remove_column "feeds", "draft"
end
