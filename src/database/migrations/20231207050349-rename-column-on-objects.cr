require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    ALTER TABLE "objects"
    RENAME COLUMN "replies" TO "replies_iri"
  STR
end

down do |db|
  db.exec <<-STR
    ALTER TABLE "objects"
    RENAME COLUMN "replies_iri" TO "replies"
  STR
end
