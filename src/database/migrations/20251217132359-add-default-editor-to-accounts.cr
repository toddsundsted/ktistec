require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "accounts", "default_editor", "TEXT"
end

down do |db|
  remove_column "accounts", "default_editor"
end
