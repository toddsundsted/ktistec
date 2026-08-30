require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "accounts", "feed_order", "TEXT"
end

down do
  remove_column "accounts", "feed_order"
end
