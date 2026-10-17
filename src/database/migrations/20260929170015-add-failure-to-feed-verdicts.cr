require "../../framework/database"

extend Ktistec::Database::Migration

up do |_db|
  add_column "feed_verdicts", "failure", "varchar(15)"
end

down do |db|
  # a failed verdict would read as an exclusion
  db.exec <<-STR
    DELETE FROM feed_verdicts
     WHERE failure IS NOT NULL
  STR
  remove_column "feed_verdicts", "failure"
end
