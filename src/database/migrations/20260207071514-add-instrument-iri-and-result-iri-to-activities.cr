require "../../framework/database"

extend Ktistec::Database::Migration

up do
  add_column "activities", "instrument_iri", "text COLLATE NOCASE"
  add_column "activities", "result_iri", "text COLLATE NOCASE"
end

down do
  remove_column "activities", "instrument_iri"
  remove_column "activities", "result_iri"
end
