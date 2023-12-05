require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE "last_times" (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "timestamp" datetime NOT NULL,
      "name" varchar(63) NOT NULL,
      "account_id" integer
    )
  STR
  db.exec <<-STR
    CREATE INDEX "idx_last_times_name"
      ON "last_times" ("name" ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE "last_times"
  STR
end
