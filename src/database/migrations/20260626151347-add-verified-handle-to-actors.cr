require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "actors", "verified_handle", "varchar(244) COLLATE NOCASE"
end

down do
  remove_column "actors", "verified_handle"
end
