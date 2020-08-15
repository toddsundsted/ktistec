require "../task"

class Task
  class Send < Task
    include Balloon::Util

    belongs_to sender, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(sender) { "missing: #{source_iri}" unless sender? }

    belongs_to activity, class_name: ActivityPub::Activity, foreign_key: subject_iri, primary_key: iri
    validates(activity) { "missing: #{subject_iri}" unless activity? }

    private PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

    private def public?(iri)
      iri == PUBLIC
    end

    private def local?(iri)
      iri.try(&.starts_with?(Balloon.host))
    end

    private def followers_path?(iri)
      iri && URI.parse(iri).path =~ /^\/actors\/#{sender.username}\/followers$/
    end

    private def recipients
      actor = ActivityPub::Actor.dereference?(activity.actor_iri)
      object = ActivityPub::Object.dereference?(activity.object_iri)

      recipients = [activity.to, activity.cc].compact.flatten

      # for remote activities, prune recipients that aren't 1) the
      # public collection, 2) the sender itself, 3) the activity's
      # actor's followers collection to which the sender belongs, 4) a
      # local followers collection to which a reply is addressed.
      unless activity.try(&.local)
        recipients.select! do |recipient|
          public?(recipient) ||
            (sender.iri == recipient) ||
            (object && local?(object.in_reply_to) && local?(recipient) && followers_path?(recipient)) ||
            (actor && actor.followers == recipient && sender.follows?(actor))
        end
      end

      if actor == sender
        recipients.delete(sender.iri)
      end

      # replace collections. replace the public collection with the
      # activity's actor's followers. replace a local collection with
      # the sender's followers. replace a remote collection with the
      # sender if the sender follows the activity's actor. simply
      # include all non-collections.
      results = [] of String
      recipients.each do |recipient|
        if public?(recipient)
          results += Relationship::Social::Follow.where(
            to_iri: actor.try(&.iri)
          ).map(&.from_iri)

        elsif local?(recipient)
          if followers_path?(recipient)
            results += Relationship::Social::Follow.where(
              to_iri: sender.iri
            ).map(&.from_iri)
          else
            results << recipient
          end

        else
          unless (target = ActivityPub::Actor.find?(recipient))
            open?(recipient) do |response|
              target = ActivityPub.from_json_ld?(response.body)
              if target.is_a?(ActivityPub::Collection)
                target =
                  actor && actor.followers == target.iri && sender.follows?(actor) ?
                  sender :
                  nil
              end
            end
          end
          if target
            results << target.iri
          end
        end
      end

      results.sort.uniq.map do |result|
        unless (actor = ActivityPub::Actor.dereference?(result))
          failures << Failure.new("recipient does not exist: #{result}")
        end
        actor
      end.compact
    end

    def perform
      recipients.each do |recipient|
        if recipient.local
          Relationship::Content::Inbox.new(
            owner: recipient,
            activity: activity,
            confirmed: true
          ).save
        elsif (inbox = recipient.inbox)
          HTTP::Client.post(
            inbox,
            Balloon::Signature.sign(sender, inbox),
            activity.to_json_ld
          )
        else
          failures << Failure.new("recipient has no inbox: #{recipient}")
        end
      end
      save
    end
  end
end
