require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "accounts", "timezone", "varchar(244) NOT NULL DEFAULT \"\""
end

down do
  remove_column "accounts", "timezone"
end
