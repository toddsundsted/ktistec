require "../task"
require "../task/mixins/transfer"

require "../../framework/constants"
require "../activity_pub/activity"
require "../activity_pub/actor"
require "../activity_pub/collection"
require "../activity_pub/object"
require "../activity_pub/object/quote_authorization"
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

      property deliver_to : Array(String)?

      def initialize(@deliver_to = [] of String)
      end
    end

    @[Persistent]
    @[Insignificant]
    property state : State { State.new }

    @[Assignable]
    @deliver_to : Array(String)?

    def deliver_to
      state.deliver_to
    end

    def deliver_to=(@deliver_to : Array(String)?)
      state.deliver_to = deliver_to
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
        if recipient == receiver.iri
          # 1. recipient is the receiver
          recipient
        elsif recipient && recipient =~ /^#{receiver.iri}\/followers$/
          # 2. recipient is the receiver's followers collection, and
          # this activity's object is a reply to an object attributed to
          # the receiver and the recipient is in all ancestor object's
          # recipients. replace with the followers.
          if (object_iri = activity.object_iri) && (reply = ActivityPub::Object.dereference?(receiver, object_iri))
            if (ancestors = ancestors(reply)) && (object = ancestors.last?)
              if (actor = object.attributed_to?(receiver, dereference: true)) && actor == receiver
                if ancestors.all? { |ancestor| [ancestor.to, ancestor.cc].compact.flatten.includes?(recipient) }
                  Relationship::Social::Follow.where(
                    object: receiver,
                    confirmed: true
                  ).select(&.actor?).map(&.actor.iri)
                end
              end
            end
          end
        elsif (sender = activity.actor?(receiver, dereference: true))
          # 3. receiver is a follower of the sender and the recipinet is
          # either the public collection or the sender's followers
          # collection.  replace with the receiver.
          if receiver.follows?(sender, confirmed: true)
            if recipient == PUBLIC
              receiver.iri
            elsif recipient && recipient == sender.followers
              receiver.iri
            end
          end
        end
      end.compact.sort!.uniq!
    end

    def perform
      if (activity = self.activity) && activity.is_a?(ActivityPub::Activity::ObjectActivity) && (object = activity.object?)
        if (quote = object.quote?(include_deleted: true) || object.quote?(receiver, dereference: true))
          if quote.attributed_to?(include_deleted: true) || quote.attributed_to?(receiver, dereference: true)
            quote.save
          end
          if !object.local? && object.attributed_to != quote.attributed_to
            if (quote_authorization = object.quote_authorization?(receiver, dereference: true))
              if quote_authorization.valid_for?(object, quote)
                quote_authorization.save
              end
            end
          end
        end
      end

      transfer activity, from: receiver, to: recipients
    end
  end
end
