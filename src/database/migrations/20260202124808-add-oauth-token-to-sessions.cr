require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "sessions", "oauth_access_token_id", "integer", index: "ASC"
end

down do
  remove_column "sessions", "oauth_access_token_id"
end
