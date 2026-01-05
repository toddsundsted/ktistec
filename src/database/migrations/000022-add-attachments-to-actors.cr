require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "actors", "attachments", "text"
end

down do
  remove_column "actors", "attachments"
end
