require "../../framework/database"
require "../../utils/database/reconcile_materialized_views"

extend Ktistec::Database::Migration

up do |db|
  Ktistec::Database::ReconcileMaterializedViews.run(db)
end

down do
end
