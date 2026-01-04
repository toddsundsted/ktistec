require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "objects", "language", "varchar(244) COLLATE NOCASE"
end

down do
  remove_column "objects", "language"
end
