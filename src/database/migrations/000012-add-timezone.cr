require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "accounts", "timezone", "varchar(244) NOT NULL DEFAULT \"\""
end

down do |db|
  remove_column "accounts", "timezone"
end
