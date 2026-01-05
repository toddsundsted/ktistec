require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "oauth_clients", "last_accessed_at", "datetime"
end

down do
  remove_column "oauth_clients", "last_accessed_at"
end
