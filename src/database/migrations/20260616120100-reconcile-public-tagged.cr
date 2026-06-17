require "../../framework/database"
require "../../rules/maintainer"
require "../../rules/view/public_tagged"

extend Ktistec::Database::Migration

up do |_db|
  Rules::Maintainer.reconcile(Rules::View::PublicTagged.instance)
end

down do |db|
  db.exec "DELETE FROM relationships WHERE type = 'Relationship::Content::PublicTagged'"
end
