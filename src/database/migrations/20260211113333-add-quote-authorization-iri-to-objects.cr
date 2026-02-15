require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "objects", "quote_authorization_iri", "text COLLATE NOCASE"
end

down do
  remove_column "objects", "quote_authorization_iri"
end
