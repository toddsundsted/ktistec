require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "actors", "featured", "text"

  # populate featured URLs for local actors
  db.exec <<-STR
    UPDATE actors
       SET featured = accounts.iri || '/featured'
      FROM accounts
     WHERE actors.iri = accounts.iri
  STR
end

down do
  remove_column "actors", "featured"
end
