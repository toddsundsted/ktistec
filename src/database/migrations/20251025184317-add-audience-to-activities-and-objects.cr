require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "activities", "audience", "text"
  add_column "objects", "audience", "text"
end

down do
  remove_column "activities", "audience"
  remove_column "objects", "audience"
end
