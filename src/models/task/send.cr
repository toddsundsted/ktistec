require "../task"

class Task
  class Send < Task
    include Balloon::Util

    belongs_to sender, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(sender) { "missing: #{source_iri}" unless sender? }

    belongs_to activity, class_name: ActivityPub::Activity, foreign_key: subject_iri, primary_key: iri
    validates(activity) { "missing: #{subject_iri}" unless activity? }

    private def local?(iri)
      iri.try(&.starts_with?(Balloon.host))
    end

    private def collection_path?(iri)
      iri && URI.parse(iri).path =~ /^\/actors\/([^\/]+)\/([^\/]+)$/
    end

    private def actor_path?(iri)
      iri && URI.parse(iri).path =~ /^\/actors\/([^\/]+)$/
    end

    private def recipients
      recipients = [activity.to, activity.cc].compact.flatten

      if (object_iri = activity.object_iri)
        unless (object = ActivityPub::Object.find?(object_iri))
          open(object_iri) do |response|
            object = ActivityPub::Object.from_json_ld?(response.body)
          end
        end
      end

      unless local?(activity.actor_iri)
        recipients.select! do |r|
          local?(r) &&
            ((object && local?(object.in_reply_to) && collection_path?(r)) ||
             (actor_path?(r)))
        end
      end

      recipients
    end

    def perform
      recipients = self.recipients
      while (recipient = recipients.shift?)
        if local?(recipient)
          case URI.parse(recipient).path
          when /^\/actors\/([^\/]+)\/([^\/]+)$/
            # if it looks like a collection, dereference the IRI and
            # add the actors in the collection to the recipients
            recipients += Relationship::Social::Follow.where(
              from_iri: "#{Balloon.host}/actors/#{$1}"
            ).map(&.to_iri)
            next
          when /^\/actors\/([^\/]+)$/
            # if it looks like an actor, dereference the IRI
            object = ActivityPub::Actor.find?(recipient)
          end
        else
          # if it's a remote entity, find it if it's a cached
          # actor, otherwise fetch it from the origin
          unless (object = ActivityPub::Actor.find?(recipient))
            open(recipient) do |response|
              object = ActivityPub.from_json_ld?(response.body)
            end
          end
        end

        if object
          if object.local && object.is_a?(ActivityPub::Actor)
            Relationship::Content::Inbox.new(
              owner: object,
              activity: activity,
              confirmed: true
            ).save
          elsif object.responds_to?(:inbox) && (inbox = object.inbox)
            HTTP::Client.post(
              inbox,
              Balloon::Signature.sign(sender, inbox),
              activity.to_json_ld
            )
          elsif object.is_a?(ActivityPub::Collection)
            # take no action
          else
            failures << Failure.new("recipient has no inbox: #{recipient}")
          end
        else
          failures << Failure.new("recipient does not exist: #{recipient}")
        end
      end

      save
    end
  end
end
