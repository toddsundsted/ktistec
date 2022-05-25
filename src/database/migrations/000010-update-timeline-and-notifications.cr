# no need to run this migration before running specs. it fixes
# production data issues that shouldn't occur during testing (and it
# pulls in so many dependencies that it really slows down building
# and running specs).
{% unless @type.has_constant? "Spectator" %}
  require "../../framework/database"
  require "../../models/relationship/content/inbox"
  require "../../models/relationship/content/outbox"
  require "../../models/relationship/content/notification"
  require "../../models/relationship/content/timeline"

  require "../../models/account"
  require "../../models/activity_pub/**"
  require "../../rules/content_rules"

  extend Ktistec::Database::Migration

  up do |db|
    Relationship::Content::Notification.all.each(&.destroy)
    Relationship::Content::Timeline.all.each(&.destroy)
    Account.all.each do |account|
      Relationship.where(%q|type in ("Relationship::Content::Inbox","Relationship::Content::Outbox") AND from_iri = ? ORDER BY created_at ASC|, account.iri).each do |relationship|
        if relationship.responds_to?(:activity) && relationship.activity?
          School::Fact.clear!
          School::Fact.assert(ContentRules::IsAddressedTo.new(relationship.activity, account.actor))
          ContentRules.new.run
        end
      end
    end
  end

  down do |db|
    # no-op
  end
{% end %}
