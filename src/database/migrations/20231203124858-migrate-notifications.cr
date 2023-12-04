require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    UPDATE relationships
       SET to_iri = (
         SELECT object_iri
           FROM activities
          WHERE iri = to_iri
       )
     WHERE type IN (
       "Relationship::Content::Notification::Hashtag",
       "Relationship::Content::Notification::Mention",
       "Relationship::Content::Notification::Thread",
       "Relationship::Content::Notification::Reply"
     )
  STR
end
