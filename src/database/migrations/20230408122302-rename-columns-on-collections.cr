require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    ALTER TABLE collections
    RENAME COLUMN first TO first_iri
  STR
  db.exec <<-STR
    ALTER TABLE collections
    RENAME COLUMN last TO last_iri
  STR
  db.exec <<-STR
    ALTER TABLE collections
    RENAME COLUMN prev TO prev_iri
  STR
  db.exec <<-STR
    ALTER TABLE collections
    RENAME COLUMN next TO next_iri
  STR
  db.exec <<-STR
    ALTER TABLE collections
    RENAME COLUMN current TO current_iri
  STR
end

down do |db|
  db.exec <<-STR
    ALTER TABLE collections
    RENAME COLUMN first_iri TO first
  STR
  db.exec <<-STR
    ALTER TABLE collections
    RENAME COLUMN last_iri TO last
  STR
  db.exec <<-STR
    ALTER TABLE collections
    RENAME COLUMN prev_iri TO prev
  STR
  db.exec <<-STR
    ALTER TABLE collections
    RENAME COLUMN next_iri TO next
  STR
  db.exec <<-STR
    ALTER TABLE collections
    RENAME COLUMN current_iri TO current
  STR
end
