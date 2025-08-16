require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "oauth_clients", "last_accessed_at", "datetime"
end

down do |db|
  remove_column "oauth_clients", "last_accessed_at"
end
