require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "objects", "quote_iri", "text COLLATE NOCASE", index: "ASC"
end

down do
  remove_column "objects", "quote_iri"
end
