require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "actors", "shared_inbox", "text"
end

down do
  remove_column "actors", "shared_inbox"
end
