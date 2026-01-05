require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "accounts", "default_editor", "TEXT"
end

down do
  remove_column "accounts", "default_editor"
end
