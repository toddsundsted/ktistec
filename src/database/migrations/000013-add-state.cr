require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "accounts", "state", "text"
end

down do |db|
  remove_column "accounts", "state"
end
