require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "actors", "shared_inbox", "text"
end

down do |db|
  remove_column "actors", "shared_inbox"
end
