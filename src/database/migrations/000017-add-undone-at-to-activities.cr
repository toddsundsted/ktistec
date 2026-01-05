require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "activities", "undone_at", "datetime"
  db.exec <<-STR
    UPDATE activities
    SET undone_at = (
      SELECT u.created_at
        FROM activities AS u
       WHERE u.type = "ActivityPub::Activity::Undo"
         AND u.object_iri = activities.iri
         AND u.actor_iri = activities.actor_iri
    )
  STR
end

down do
  remove_column "activities", "undone_at"
end
