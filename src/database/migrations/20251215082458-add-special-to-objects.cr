require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "objects", "special", "text"
end

down do |db|
  remove_column "objects", "special"
end
