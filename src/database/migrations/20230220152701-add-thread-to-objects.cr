require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "objects", "thread", "text COLLATE NOCASE", index: "ASC"
end

down do |db|
  remove_column "objects", "thread"
end
