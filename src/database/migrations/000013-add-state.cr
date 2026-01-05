require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "accounts", "state", "text"
end

down do
  remove_column "accounts", "state"
end
