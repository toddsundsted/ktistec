require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    UPDATE tasks
       SET type = 'Task::Feed::CollectDrafts'
     WHERE type = 'Task::CollectFeedDrafts'
  STR
  db.exec <<-STR
    UPDATE tasks
       SET type = 'Task::Feed::CollectOrphans'
     WHERE type = 'Task::CollectFeedOrphans'
  STR
end

down do |db|
  db.exec <<-STR
    UPDATE tasks
       SET type = 'Task::CollectFeedDrafts'
     WHERE type = 'Task::Feed::CollectDrafts'
  STR
  db.exec <<-STR
    UPDATE tasks
       SET type = 'Task::CollectFeedOrphans'
     WHERE type = 'Task::Feed::CollectOrphans'
  STR
end
