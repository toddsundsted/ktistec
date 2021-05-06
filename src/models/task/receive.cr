require "../task"

require "../../framework/constants"
require "../../framework/signature"
require "../activity_pub/activity"
require "../activity_pub/actor"
require "../activity_pub/collection"
require "../activity_pub/object"
require "../relationship/content/inbox"
require "../relationship/social/follow"

class Task
  class Receive < Task
    include Ktistec::Constants
    include Ktistec::Open

    belongs_to receiver, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(receiver) { "missing: #{source_iri}" unless receiver? }

    belongs_to activity, class_name: ActivityPub::Activity, foreign_key: subject_iri, primary_key: iri
    validates(activity) { "missing: #{subject_iri}" unless activity? }

    class State
      include JSON::Serializable

      property deliver_to : Array(String)

      def initialize(@deliver_to = [] of String)
      end
    end

    @[Assignable]
    property deliver_to : Array(String)?

    def deliver_to
      @deliver_to ||=
        if (state = self.state)
          State.from_json(state).deliver_to
        end
    end

    def deliver_to=(@deliver_to : Array(String)?)
      state = (temp = self.state) ? State.from_json(temp) : State.new
      state.deliver_to = deliver_to if deliver_to
      self.state = state.to_json
      @deliver_to
    end

    private def ancestors(object)
      ([] of typeof(object)).tap do |ancestors|
        while object && (object = object.in_reply_to?(dereference: true))
          ancestors << object
        end
      end
    end

    def recipients
      [activity.to, activity.cc, self.deliver_to].flatten.flat_map do |recipient|
        # 1. recipient is the receiver
        if recipient == receiver.iri
          recipient
        # 2. recipient is the receiver's followers collection, and
        # this activity's object is a reply to an object attributed to
        # the receiver and the recipient is in all ancestor object's
        # recipients. replace with the followers.
        elsif recipient && recipient =~ /^#{receiver.iri}\/followers$/
          if (reply = ActivityPub::Object.dereference?(activity.object_iri))
            if (ancestors = ancestors(reply)) && (object = ancestors.last?)
              if (actor = ActivityPub::Actor.dereference?(object.attributed_to_iri)) && actor == receiver
                if ancestors.all? { |ancestor| [ancestor.to, ancestor.cc].compact.flatten.includes?(recipient) }
                  Relationship::Social::Follow.where(
                    to_iri: receiver.iri,
                    confirmed: true
                  ).map(&.from_iri)
                end
              end
            end
          end
        # 3. receiver is a follower and the recipinet is either the
        # public collection or the sender's followers collection.
        # replace with the receiver.
        elsif (sender = ActivityPub::Actor.dereference?(activity.actor_iri))
          if receiver.follows?(sender, confirmed: true)
            if recipient == PUBLIC
              receiver.iri
            elsif recipient
              unless (target = ActivityPub::Actor.find?(recipient))
                open?(recipient) do |response|
                  target = ActivityPub.from_json_ld?(response.body)
                  if target.is_a?(ActivityPub::Collection) && target.iri == sender.followers
                    receiver.iri
                  end
                end
              end
            end
          end
        end
      end.compact.sort.uniq
    end

    # if the activity is a delete, the object will already have been
    # deleted so herein and throughout don't validate and save the
    # associated models -- they shouldn't have changed anyway.

    def deliver(to recipients)
      recipients.each do |recipient|
        unless (actor = ActivityPub::Actor.dereference?(recipient))
          message = "recipient does not exist: #{recipient}"
          failures << Failure.new(message)
          Log.info { message }
          next
        end
        if actor.local?
          Relationship::Content::Inbox.new(
            owner: actor,
            activity: activity,
            confirmed: true
          ).save(skip_associated: true)
        elsif (inbox = actor.inbox)
          body = activity.to_json_ld
          headers = Ktistec::Signature.sign(receiver, inbox, body)
          response = HTTP::Client.post(inbox, headers, body)
          unless response.success?
            message = "failed to deliver to #{inbox}: [#{response.status_code}] #{response.body}"
            failures << Failure.new(message)
            Log.info { message }
          end
        else
          message = "recipient doesn't have an inbox: #{recipient}"
          failures << Failure.new(message)
          Log.info { message }
        end
      end
    end

    def perform
      deliver to: recipients
    end
  end
end
