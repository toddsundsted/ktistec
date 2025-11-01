require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "accounts", "auto_approve_followers", "BOOLEAN NOT NULL DEFAULT 0"
end

down do |db|
  remove_column "accounts", "auto_approve_followers"
end
