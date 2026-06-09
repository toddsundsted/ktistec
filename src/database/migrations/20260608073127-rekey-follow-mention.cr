require "../../framework/database"
require "../../utils/database/rekey_follow_mention"

extend Ktistec::Database::Migration

up do |db|
  Ktistec::Database::RekeyFollowMention.run(db)
end

down do |db|
  Ktistec::Database::RekeyFollowMention.revert(db)
end
