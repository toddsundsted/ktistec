require "../task"

class Task
  class Send < Task
    include Balloon::Util

    belongs_to actor, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(actor) { "missing: #{source_iri}" unless actor? }

    belongs_to activity, class_name: ActivityPub::Activity, foreign_key: subject_iri, primary_key: iri
    validates(activity) { "missing: #{subject_iri}" unless activity? }

    def perform
      recipients = [activity.to, activity.cc].compact.flatten

      while (recipient = recipients.shift?)
        unless (object = ActivityPub::Actor.find?(recipient))
          open(recipient) do |response|
            if (object = ActivityPub::Actor.from_json_ld?(response.body, include_key: true))
              object.save
            end
          end
        end

        if object
          if object.local
            Relationship::Content::Inbox.new(
              owner: object,
              activity: activity
            ).save
          elsif (inbox = object.inbox)
            HTTP::Client.post(
              inbox,
              Balloon::Signature.sign(actor, inbox),
              activity.to_json_ld
            )
          else
            failures << Failure.new("recipient has no inbox: #{recipient}")
          end
        else
          failures << Failure.new("recipient not found: #{recipient}")
        end
      end
      save
    end
  end
end
