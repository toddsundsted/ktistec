require "../models/account"
require "../models/relationship/content/inbox"
require "../models/relationship/content/outbox"
require "../models/relationship/content/notification"
require "../models/relationship/content/timeline"
# all models must be loaded before rules are defined!
require "../models/activity_pub/**"
require "../rules/content_rules"

module Ktistec
  # Utilities for maintaining the database.
  #
  module Database
    # Destroy and recreate timeline and notifications.
    #
    def self.recreate_timeline_and_notifications
      Relationship::Content::Notification.all.each(&.destroy)
      Relationship::Content::Timeline.all.each(&.destroy)
      Account.all.each do |account|
        Relationship.where(%Q|type in ("#{Relationship::Content::Inbox}","#{Relationship::Content::Outbox}") AND from_iri = ? ORDER BY created_at ASC|, account.iri).each do |relationship|
          if relationship.responds_to?(:activity) && relationship.activity?
            School::Fact.clear!
            School::Fact.assert(ContentRules::IsAddressedTo.new(relationship.activity, account.actor))
            ContentRules.new.run
          end
        end
        # adjust timestamps
        Relationship::Content::Notification.all.each do |notification|
          if (created_at = notification.activity?.try(&.created_at))
            notification.created_at = created_at
            notification.save
          end
        end
        Relationship::Content::Timeline.all.each do |timeline|
          if (created_at = timeline.object?.try(&.created_at))
            timeline.created_at = created_at
            timeline.save
          end
        end
      end
    end
  end
end
