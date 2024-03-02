PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE options (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE migrations (id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO migrations VALUES(0,'create-accounts');
INSERT INTO migrations VALUES(1,'create-sessions');
INSERT INTO migrations VALUES(2,'create-actors');
INSERT INTO migrations VALUES(3,'create-relationships');
INSERT INTO migrations VALUES(4,'create-collections');
INSERT INTO migrations VALUES(5,'create-objects');
INSERT INTO migrations VALUES(6,'create-activities');
INSERT INTO migrations VALUES(7,'create-tasks');
INSERT INTO migrations VALUES(8,'create-tags');
INSERT INTO migrations VALUES(9,'create-tag-statistics');
INSERT INTO migrations VALUES(10,'update-timeline-and-notifications');
INSERT INTO migrations VALUES(11,'create-points');
INSERT INTO migrations VALUES(12,'add-timezone');
INSERT INTO migrations VALUES(13,'add-state');
INSERT INTO migrations VALUES(14,'add-blocked-at-to-actors');
INSERT INTO migrations VALUES(15,'add-blocked-at-to-objects');
INSERT INTO migrations VALUES(16,'add-name-to-objects');
INSERT INTO migrations VALUES(17,'add-undone-at-to-activities');
INSERT INTO migrations VALUES(18,'add-index-on-attributed-to-iri-to-activities');
INSERT INTO migrations VALUES(19,'update-timeline-and-notifications');
INSERT INTO migrations VALUES(20,'add-indexes-on-actor-iri-and-target-iri-to-activities');
INSERT INTO migrations VALUES(21,'add-unique-indexes-on-actors-and-objects');
INSERT INTO migrations VALUES(22,'add-attachments-to-actors');
INSERT INTO migrations VALUES(20230108194422,'create-filter-terms');
INSERT INTO migrations VALUES(20230220152701,'add-thread-to-objects');
INSERT INTO migrations VALUES(20230227140933,'migrate-notification-types');
INSERT INTO migrations VALUES(20230227145139,'migrate-timeline-types');
INSERT INTO migrations VALUES(20230228185154,'fix-index-on-relationships');
INSERT INTO migrations VALUES(20230408122302,'rename-columns-on-collections');
INSERT INTO migrations VALUES(20231028132259,'fix-indexes-on-relationships');
INSERT INTO migrations VALUES(20231112092830,'fix-indexes-on-relationships');
INSERT INTO migrations VALUES(20231112170935,'fix-indexes-on-tasks');
INSERT INTO migrations VALUES(20231112173913,'add-index-on-sessions');
INSERT INTO migrations VALUES(20231112212330,'add-index-to-relationships');
INSERT INTO migrations VALUES(20231122145024,'add-down-at-to-actors');
INSERT INTO migrations VALUES(20231127151538,'add-index-on-iri-to-accounts');
INSERT INTO migrations VALUES(20231203124858,'migrate-notifications');
INSERT INTO migrations VALUES(20231204074106,'create-last-times');
INSERT INTO migrations VALUES(20231204140457,'migrate-account-state');
INSERT INTO migrations VALUES(20231207050349,'rename-column-on-objects');
INSERT INTO migrations VALUES(20231218135321,'add-index-on-subject-iri-to-tasks');
INSERT INTO migrations VALUES(20240118055642,'fix-indexes-on-relationships');
INSERT INTO migrations VALUES(20240119121753,'remove-index-on-created-at-from-tasks');
CREATE TABLE accounts (
    id integer PRIMARY KEY AUTOINCREMENT,
    created_at datetime NOT NULL,
    updated_at datetime NOT NULL,
    username varchar(255) NOT NULL,
    encrypted_password varchar(255) NOT NULL,
    iri varchar(255) NOT NULL COLLATE NOCASE,
    timezone varchar(244) NOT NULL DEFAULT "",
    state text
  );
CREATE TABLE sessions (
    id integer PRIMARY KEY AUTOINCREMENT,
    created_at datetime NOT NULL,
    updated_at datetime NOT NULL,
    body_json text NOT NULL,
    session_key varchar(22) NOT NULL,
    account_id integer
  );
CREATE TABLE actors (
    "id" integer PRIMARY KEY AUTOINCREMENT,
    "created_at" datetime NOT NULL,
    "updated_at" datetime NOT NULL,
    "type" varchar(63) NOT NULL,
    "iri" varchar(255) NOT NULL COLLATE NOCASE,
    "username" varchar(255),
    "pem_public_key" text,
    "pem_private_key" text,
    "inbox" text,
    "outbox" text,
    "following" text,
    "followers" text,
    "name" text,
    "summary" text,
    "icon" text,
    "image" text,
    "urls" text,
    "deleted_at" datetime,
    "blocked_at" datetime,
    "attachments" text,
    "down_at" datetime
  );
CREATE TABLE relationships (
    id integer PRIMARY KEY AUTOINCREMENT,
    created_at datetime NOT NULL,
    updated_at datetime NOT NULL,
    type varchar(63) NOT NULL,
    from_iri varchar(255) NOT NULL COLLATE NOCASE,
    to_iri varchar(255) NOT NULL COLLATE NOCASE,
    confirmed boolean,
    visible boolean
  );
CREATE TABLE collections (
    id integer PRIMARY KEY AUTOINCREMENT,
    created_at datetime NOT NULL,
    updated_at datetime NOT NULL,
    iri varchar(255) NOT NULL COLLATE NOCASE,
    items_iris text,
    total_items integer,
    first_iri varchar(255),
    last_iri varchar(255),
    prev_iri varchar(255),
    next_iri varchar(255),
    current_iri varchar(255)
  );
CREATE TABLE objects (
    "id" integer PRIMARY KEY AUTOINCREMENT,
    "created_at" datetime NOT NULL,
    "updated_at" datetime NOT NULL,
    "type" varchar(63) NOT NULL,
    "iri" varchar(255) NOT NULL COLLATE NOCASE,
    "visible" boolean,
    "published" datetime,
    "attributed_to_iri" text COLLATE NOCASE,
    "in_reply_to_iri" text COLLATE NOCASE,
    "replies_iri" text,
    "to" text,
    "cc" text,
    "summary" text,
    "content" text,
    "media_type" text,
    "source" text,
    "attachments" text,
    "urls" text,
    "deleted_at" datetime,
    "blocked_at" datetime,
    "name" text,
    "thread" text COLLATE NOCASE
  );
CREATE TABLE activities (
    "id" integer PRIMARY KEY AUTOINCREMENT,
    "created_at" datetime NOT NULL,
    "updated_at" datetime NOT NULL,
    "type" varchar(63) NOT NULL,
    "iri" varchar(255) NOT NULL COLLATE NOCASE,
    "visible" boolean,
    "published" datetime,
    "actor_iri" text COLLATE NOCASE,
    "object_iri" text COLLATE NOCASE,
    "target_iri" text COLLATE NOCASE,
    "to" text,
    "cc" text,
    "summary" text,
    "undone_at" datetime
  );
CREATE TABLE tasks (
    "id" integer PRIMARY KEY AUTOINCREMENT,
    "created_at" datetime NOT NULL,
    "updated_at" datetime NOT NULL,
    "type" varchar(63) NOT NULL,
    "source_iri" text COLLATE NOCASE,
    "subject_iri" text COLLATE NOCASE,
    "failures" text,
    "running" boolean DEFAULT 0,
    "complete" boolean DEFAULT 0,
    "backtrace" text,
    "next_attempt_at" datetime,
    "last_attempt_at" datetime,
    "state" text
  );
CREATE TABLE tags (
    "id" integer PRIMARY KEY AUTOINCREMENT,
    "created_at" datetime NOT NULL,
    "updated_at" datetime NOT NULL,
    "subject_iri" text NOT NULL COLLATE NOCASE,
    "type" varchar(99) NOT NULL,
    "name" varchar(99) NOT NULL COLLATE NOCASE,
    "href" text
  );
CREATE TABLE tag_statistics (
    "type" varchar(99) NOT NULL,
    "name" varchar(99) NOT NULL COLLATE NOCASE,
    "count" integer,
    PRIMARY KEY("type", "name")
  ) WITHOUT ROWID;
CREATE TABLE points (
    "id" integer PRIMARY KEY AUTOINCREMENT,
    "chart" varchar(63) NOT NULL,
    "timestamp" datetime NOT NULL,
    "value" integer NOT NULL
  );
CREATE TABLE filter_terms (
    "id" integer PRIMARY KEY AUTOINCREMENT,
    "created_at" datetime NOT NULL,
    "updated_at" datetime NOT NULL,
    "actor_id" integer,
    "term" text NOT NULL
  );
CREATE TABLE last_times (
    "id" integer PRIMARY KEY AUTOINCREMENT,
    "created_at" datetime NOT NULL,
    "updated_at" datetime NOT NULL,
    "timestamp" datetime NOT NULL,
    "name" varchar(63) NOT NULL,
    "account_id" integer
  );
CREATE INDEX idx_accounts_iri
    ON accounts (iri ASC);
CREATE UNIQUE INDEX idx_accounts_username
    ON accounts (username ASC);
CREATE UNIQUE INDEX idx_sessions_session_key
    ON sessions (session_key ASC);
CREATE INDEX idx_sessions_account_id
    ON sessions (account_id ASC);
CREATE INDEX idx_sessions_updated_at
    ON sessions (updated_at DESC);
CREATE INDEX idx_actors_username
    ON actors (username ASC);
CREATE INDEX idx_relationships_to_iri
    ON relationships (to_iri ASC);
CREATE INDEX idx_relationships_type
    ON relationships (type ASC);
CREATE UNIQUE INDEX idx_collections_iri
    ON collections (iri ASC);
CREATE INDEX idx_objects_in_reply_to_iri
    ON objects (in_reply_to_iri ASC);
CREATE INDEX idx_objects_published
    ON objects (published ASC);
CREATE INDEX idx_objects_thread
    ON objects (thread ASC);
CREATE UNIQUE INDEX idx_activities_iri
    ON activities (iri ASC);
CREATE INDEX idx_activities_object_iri
    ON activities (object_iri ASC);
CREATE INDEX idx_tasks_running_complete_backtrace
    ON tasks (running ASC, complete ASC, backtrace ASC);
CREATE INDEX idx_tasks_subject_iri
    ON tasks (subject_iri ASC);
CREATE INDEX idx_tags_type_subject_iri
    ON tags (type ASC, subject_iri ASC);
CREATE INDEX idx_tags_type_name
    ON tags (type ASC, name ASC);
CREATE INDEX idx_points_chart_timestamp
    ON points (chart ASC, timestamp ASC);
CREATE INDEX idx_objects_attributed_to_iri
    ON objects (attributed_to_iri ASC);
CREATE INDEX idx_activities_actor_iri
    ON activities (actor_iri ASC);
CREATE INDEX idx_activities_target_iri
    ON activities (target_iri ASC);
CREATE UNIQUE INDEX idx_actors_iri
    ON actors (iri ASC);
CREATE UNIQUE INDEX idx_objects_iri
    ON objects (iri ASC);
CREATE INDEX idx_filter_terms_actor_id
    ON filter_terms (actor_id ASC);
CREATE INDEX idx_last_times_name
    ON last_times (name ASC);
COMMIT;
