require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "accounts", "language", "varchar(244) COLLATE NOCASE"
end

down do
  remove_column "accounts", "language"
end
