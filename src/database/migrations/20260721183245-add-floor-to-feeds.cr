require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "feeds", "floor", "datetime"
end

down do
  remove_column "feeds", "floor"
end
