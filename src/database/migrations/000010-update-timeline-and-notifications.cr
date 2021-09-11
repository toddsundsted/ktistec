# no need to run this migration before running specs. it fixes
# production data issues that shouldn't occur during testing (and it
# pulls in so many dependencies that it really slows down building
# and running specs).
{% unless @type.has_constant? "Spectator" %}
  require "../../framework/database"
  require "../../models/activity_pub/**"
  require "../../models/relationship/content/timeline"
  require "../../models/relationship/content/notification"

  extend Ktistec::Database::Migration

  up do |db|
    Relationship::Content::Timeline.all.each do |timeline|
      if (timeline = Relationship::Content::Timeline.can_destroy?(timeline.from_iri, timeline.to_iri))
        timeline.destroy
      end
    end
    Relationship::Content::Notification.all.each do |notification|
      if (notification = Relationship::Content::Notification.can_destroy?(notification.from_iri, notification.to_iri))
        notification.destroy
      end
    end
  end

  down do |db|
    # no-op
  end
{% end %}
