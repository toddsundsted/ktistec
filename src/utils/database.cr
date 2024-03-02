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
    def self.recreate_timeline_and_notifications(limit = 1000)
      query = <<-QUERY
        type IN ("#{Relationship::Content::Inbox}","#{Relationship::Content::Outbox}")
        AND from_iri = ?
        AND id > ?
        ORDER BY id ASC
        LIMIT ?
      QUERY

      Relationship::Content::Notification.all.each(&.destroy)
      Relationship::Content::Timeline.all.each(&.destroy)

      Account.all.each do |account|
        i = 0
        done = false
        last = 0
        while !done
          i += 1
          done = true
          Relationship.where(query, account.iri, last, limit).each do |relationship|
            done = false
            last = relationship.id
            if relationship.responds_to?(:activity?) && (activity = relationship.activity?)
              begin
                ContentRules.new.run do
                  assert ContentRules::InMailboxOf.new(activity, account.actor)
                end
              rescue ex
                puts "Exception while running rules: " + ex.inspect_with_backtrace
              end
            end
          end
          Log.info { "Batch #{i} complete" }
        end

        # adjust timestamps
        Relationship::Content::Notification.all.each do |notification|
          if notification.responds_to?(:activity?) && (created_at = notification.activity?.try(&.created_at))
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
