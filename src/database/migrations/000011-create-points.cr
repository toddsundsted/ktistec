require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE points (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "chart" varchar(63) NOT NULL,
      "timestamp" datetime NOT NULL,
      "value" integer NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE INDEX idx_points_chart_timestamp
      ON points (chart ASC, timestamp ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE points
  STR
end
