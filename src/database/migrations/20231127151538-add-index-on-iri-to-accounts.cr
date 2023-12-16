require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_accounts_iri
      ON accounts (iri ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX idx_accounts_iri
  STR
end
