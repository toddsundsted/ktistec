require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "accounts", "language", "varchar(244) COLLATE NOCASE"
end

down do |db|
  remove_column "accounts", "language"
end
