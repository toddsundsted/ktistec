# no need to run this migration before running specs. it fixes
# production data issues that shouldn't occur during testing (and it
# pulls in so many dependencies that it really slows down building
# and running specs).
{% unless @type.has_constant? "Spectator" %}
  require "../../utils/database"

  extend Ktistec::Database::Migration

  up do |db|
    Ktistec::Database.recreate_timeline_and_notifications
  end

  down do |db|
    # no-op
  end
{% end %}
