require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "accounts", "manually_approve_quotes", "BOOLEAN NOT NULL DEFAULT 1"
end

down do
  remove_column "accounts", "manually_approve_quotes"
end
