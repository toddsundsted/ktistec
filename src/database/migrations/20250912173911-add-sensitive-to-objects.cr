require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "objects", "sensitive", "boolean DEFAULT 0"
end

down do |db|
  remove_column "objects", "sensitive"
end
