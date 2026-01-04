require "json"

require "../../framework/database"

extend Ktistec::Database::Migration

struct Temp_20231204140457  # ameba:disable Naming/TypeNames
  include DB::Serializable

  struct State
    include JSON::Serializable

    property last_timeline_checked_at : Time?
    property last_notifications_checked_at : Time?
  end

  property id : Int64
  property state : State
end

up do |db|
  results = Array(Temp_20231204140457).new.tap do |array|
    db.query(%q|SELECT "id", "state" FROM "accounts" WHERE "state" IS NOT NULL|) do |rs|
      rs.each do
        array << rs.read(Temp_20231204140457)
      end
    end
  end
  results.each do |result|
    if (last_timeline_checked_at = result.state.last_timeline_checked_at)
      db.exec(
        %q|INSERT INTO "last_times" ("created_at", "updated_at", "account_id", "name", "timestamp") VALUES (CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?, ?, ?)|,
        result.id, "last_timeline_checked_at", last_timeline_checked_at
      )
    end
    if (last_notifications_checked_at = result.state.last_notifications_checked_at)
      db.exec(
        %q|INSERT INTO "last_times" ("created_at", "updated_at", "account_id", "name", "timestamp") VALUES (CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?, ?, ?)|,
        result.id, "last_notifications_checked_at", last_notifications_checked_at
      )
    end
  end
end

down do |db|
  db.exec <<-STR
    DELETE FROM "last_times"
  STR
end
