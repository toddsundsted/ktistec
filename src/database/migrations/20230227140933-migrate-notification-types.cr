require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    UPDATE relationships
       SET type = "Relationship::Content::Notification::Follow"
     WHERE id IN (
       SELECT n.id
         FROM relationships AS n
         JOIN activities AS a
           ON a.iri = n.to_iri
          AND a.type = "ActivityPub::Activity::Follow"
        WHERE n.type = "Relationship::Content::Notification"
     )
  STR
  db.exec <<-STR
    UPDATE relationships
       SET type = "Relationship::Content::Notification::Like"
     WHERE id IN (
       SELECT n.id
         FROM relationships AS n
         JOIN activities AS a
           ON a.iri = n.to_iri
          AND a.type = "ActivityPub::Activity::Like"
        WHERE n.type = "Relationship::Content::Notification"
     )
  STR
  db.exec <<-STR
    UPDATE relationships
       SET type = "Relationship::Content::Notification::Announce"
     WHERE id IN (
       SELECT n.id
         FROM relationships AS n
         JOIN activities AS a
           ON a.iri = n.to_iri
          AND a.type = "ActivityPub::Activity::Announce"
        WHERE n.type = "Relationship::Content::Notification"
     )
  STR
  db.exec <<-STR
    UPDATE relationships
       SET type = "Relationship::Content::Notification::Reply"
     WHERE id IN (
       SELECT n.id
         FROM relationships AS n
         JOIN activities AS a
           ON a.iri = n.to_iri
          AND a.type = "ActivityPub::Activity::Create"
         JOIN objects AS r
           ON r.iri = a.object_iri
         JOIN objects AS o
           ON o.iri = r.in_reply_to_iri
          AND o.attributed_to_iri = n.from_iri
        WHERE n.type = "Relationship::Content::Notification"
     )
  STR
  db.exec <<-STR
    UPDATE relationships
       SET type = "Relationship::Content::Notification::Mention"
     WHERE id IN (
       SELECT n.id
         FROM relationships AS n
         JOIN activities AS a
           ON a.iri = n.to_iri
          AND a.type = "ActivityPub::Activity::Create"
         JOIN objects AS r
           ON r.iri = a.object_iri
         JOIN tags AS t
           ON t.subject_iri = r.iri
          AND t.href = n.from_iri
          AND t.type = "Tag::Mention"
        WHERE n.type = "Relationship::Content::Notification"
     )
  STR
end

down do |db|
  db.exec <<-STR
    UPDATE relationships
       SET type = "Relationship::Content::Notification"
     WHERE type LIKE "Relationship::Content::Notification::%"
  STR
end
