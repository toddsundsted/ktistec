require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    UPDATE relationships
       SET type = "Relationship::Content::Timeline::Announce"
     WHERE id IN (
       SELECT t.id
         FROM relationships AS t
         JOIN objects AS o
           ON o.iri = t.to_iri
         JOIN activities AS a
           ON a.id = (
               SELECT a.id
                 FROM activities AS a
                 JOIN relationships AS r
                   ON r.to_iri = a.iri
                  AND r.type IN ("Relationship::Content::Inbox", "Relationship::Content::Outbox")
                WHERE a.object_iri = o.iri
                  AND a.type IN ("ActivityPub::Activity::Announce", "ActivityPub::Activity::Create")
             ORDER BY a.created_at ASC
                LIMIT 1
           )
        WHERE t.type = "Relationship::Content::Timeline"
          AND a.type = "ActivityPub::Activity::Announce"
     )
  STR
  db.exec <<-STR
    UPDATE relationships
       SET type = "Relationship::Content::Timeline::Create"
     WHERE id IN (
       SELECT t.id
         FROM relationships AS t
         JOIN objects AS o
           ON o.iri = t.to_iri
         JOIN activities AS a
           ON a.id = (
               SELECT a.id
                 FROM activities AS a
                 JOIN relationships AS r
                   ON r.to_iri = a.iri
                  AND r.type IN ("Relationship::Content::Inbox", "Relationship::Content::Outbox")
                WHERE a.object_iri = o.iri
                  AND a.type IN ("ActivityPub::Activity::Announce", "ActivityPub::Activity::Create")
             ORDER BY a.created_at ASC
                LIMIT 1
           )
        WHERE t.type = "Relationship::Content::Timeline"
          AND a.type = "ActivityPub::Activity::Create"
     )
  STR
end

down do |db|
  db.exec <<-STR
    UPDATE relationships
       SET type = "Relationship::Content::Timeline"
     WHERE type LIKE "Relationship::Content::Timeline::%"
  STR
end
