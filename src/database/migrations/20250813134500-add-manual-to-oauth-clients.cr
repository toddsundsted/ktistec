require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "oauth_clients", "manual", "boolean NOT NULL DEFAULT 0"
end

down do
  remove_column "oauth_clients", "manual"
end
