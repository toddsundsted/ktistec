require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "activities", "audience", "text"
  add_column "objects", "audience", "text"
end

down do |db|
  remove_column "activities", "audience"
  remove_column "objects", "audience"
end
