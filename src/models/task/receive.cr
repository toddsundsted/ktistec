require "../task"
require "../task/mixins/transfer"

require "../../framework/constants"
require "../activity_pub/activity"
require "../activity_pub/actor"
require "../activity_pub/collection"
require "../activity_pub/object"
require "../relationship/social/follow"

class Task
  class Receive < Task
    include Ktistec::Constants
    include Task::ConcurrentTask
    include Task::Transfer

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
        while object && (object = object.in_reply_to?(receiver, dereference: true))
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
          if (object_iri = activity.object_iri) && (reply = ActivityPub::Object.dereference?(receiver, object_iri))
            if (ancestors = ancestors(reply)) && (object = ancestors.last?)
              if (attributed_to_iri = object.attributed_to_iri) && (actor = ActivityPub::Actor.dereference?(receiver, attributed_to_iri)) && actor == receiver
                if ancestors.all? { |ancestor| [ancestor.to, ancestor.cc].compact.flatten.includes?(recipient) }
                  Relationship::Social::Follow.where(
                    to_iri: receiver.iri,
                    confirmed: true
                  ).select(&.actor?).map(&.actor.iri)
                end
              end
            end
          end
        # 3. receiver is a follower and the recipinet is either the
        # public collection or the sender's followers collection.
        # replace with the receiver.
        elsif (actor_iri = activity.actor_iri) && (sender = ActivityPub::Actor.dereference?(receiver, actor_iri))
          if receiver.follows?(sender, confirmed: true)
            if recipient == PUBLIC
              receiver.iri
            elsif recipient
              unless (target = ActivityPub::Actor.find?(recipient))
                if (target = ActivityPub::Collection.dereference?(receiver, recipient)) && target.iri == sender.followers
                  receiver.iri
                end
              end
            end
          end
        end
      end.compact.sort.uniq
    end

    def perform
      transfer activity, from: receiver, to: recipients
    end
  end
end
