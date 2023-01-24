require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "actors", "attachments", "text"
end

down do |db|
  remove_column "actors", "attachments"
end
