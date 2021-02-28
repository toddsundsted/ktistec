require "../task"
require "../../framework/signature"
require "../activity_pub/activity"
require "../activity_pub/collection"
require "../activity_pub/actor"
require "../activity_pub/object"

class Task
  class Deliver < Task
    include Ktistec::Open

    belongs_to sender, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(sender) { "missing: #{source_iri}" unless sender? }

    belongs_to activity, class_name: ActivityPub::Activity, foreign_key: subject_iri, primary_key: iri
    validates(activity) { "missing: #{subject_iri}" unless activity? }

    private PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

    private def public?(iri)
      iri == PUBLIC
    end

    private def local?(iri)
      iri.try(&.starts_with?(Ktistec.host))
    end

    private def followers_path?(iri)
      iri && URI.parse(iri).path =~ /^\/actors\/#{sender.username}\/followers$/
    end

    class State
      include JSON::Serializable

      property deliver_to : Array(String)

      def initialize(@deliver_to = [] of String)
      end
    end

    @[Assignable]
    property deliver_to : Array(String)?

    def deliver_to
      @deliver_to ||= (temp = self.state.presence) ?
        State.from_json(temp).deliver_to :
        nil
    end

    def deliver_to=(@deliver_to : Array(String)?)
      state = (temp = self.state.presence) ?
        State.from_json(temp) :
        State.new
      state.deliver_to = deliver_to if deliver_to
      self.state = state.to_json
      deliver_to
    end

    private def recipients
      actor = ActivityPub::Actor.dereference?(activity.actor_iri)
      object = ActivityPub::Object.dereference?(activity.object_iri)

      recipients = [activity.to, activity.cc, self.deliver_to].compact.flatten

      # for remote activities, prune recipients that aren't 1) the
      # public collection, 2) the sender itself, 3) a local followers
      # collection to which a reply is addressed, 4) the activity's
      # actor's followers collection.
      unless activity.try(&.local?)
        recipients.select! do |recipient|
          public?(recipient) ||
            (sender.iri == recipient) ||
            (object && local?(object.in_reply_to_iri) && local?(recipient) && followers_path?(recipient)) ||
            (actor && actor.followers == recipient)
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
            to_iri: actor.try(&.iri),
            confirmed: true
          ).map(&.from_iri)

        elsif local?(recipient)
          if followers_path?(recipient)
            results += Relationship::Social::Follow.where(
              to_iri: sender.iri,
              confirmed: true
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
                  actor && actor.followers == target.iri && sender.follows?(actor, confirmed: true) ?
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
          message = "recipient does not exist: #{result}"
          failures << Failure.new(message)
          Log.debug { message }
        end
        actor
      end.compact
    end

    def perform
      recipients.each do |recipient|
        if recipient.local?
          Relationship::Content::Inbox.new(
            owner: recipient,
            activity: activity,
            confirmed: true
          ).save
        elsif (inbox = recipient.inbox)
          body = activity.to_json_ld
          headers = Ktistec::Signature.sign(sender, inbox, body)
          response = HTTP::Client.post(inbox, headers, body)
          unless response.success?
            message = "failed to deliver to #{inbox}: #{response.body}"
            failures << Failure.new(message)
            Log.debug { message }
          end
        else
          message = "recipient has no inbox: #{recipient}"
          failures << Failure.new(message)
          Log.debug { message }
        end
      end
    end
  end
end
