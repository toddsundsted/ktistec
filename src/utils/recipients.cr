require "../ktistec/constants"
require "../models/account"
require "../models/activity_pub/activity"
require "../models/activity_pub/actor"
require "../models/activity_pub/object"
require "../models/relationship/social/follow"

module Ktistec
  # Recipient expansion and partitioning shared by tasks and
  # processors.
  #
  module Recipients
    # Expands an outbound activity's recipient fields into a sorted,
    # deduplicated list of actor IRIs reachable from this server.
    #
    def self.for_deliver(activity : ActivityPub::Activity, sender : ActivityPub::Actor) : Array(String)
      [activity.to, activity.cc, activity.audience, sender.iri].flatten.flat_map do |recipient|
        if recipient == Ktistec::Constants::PUBLIC
          # no-op
        elsif recipient == sender.iri
          sender.iri
        elsif recipient && (actor = ActivityPub::Actor.find?(recipient))
          actor.iri
        elsif recipient && recipient =~ /^#{sender.iri}\/followers$/
          Relationship::Social::Follow.where(
            object: sender,
            confirmed: true,
          ).select(&.actor?).map(&.actor.iri)
        end
      end.compact.sort!.uniq!
    end

    # Expands an inbound activity's recipient fields into a sorted,
    # deduplicated list of actor IRIs reachable from this server.
    #
    def self.for_receive(activity : ActivityPub::Activity, receiver : ActivityPub::Actor, deliver_to : Array(String)?) : Array(String)
      [activity.to, activity.cc, deliver_to].flatten.flat_map do |recipient|
        if recipient == receiver.iri
          # 1. recipient is the receiver
          recipient
        elsif recipient && recipient =~ /^#{receiver.iri}\/followers$/
          # 2. recipient is the receiver's followers collection. when
          # the activity's object is a reply rooted at an object
          # attributed to the receiver, and every ancestor also
          # addresses the followers collection, replace with the
          # receiver's followers.
          if (object_iri = activity.object_iri) && (reply = ActivityPub::Object.find?(object_iri))
            if (root = ActivityPub::Object.find?(reply.thread || reply.iri))
              if (attributed = root.attributed_to?) && attributed == receiver
                ancestors = reply.ancestors(include_deleted: true, include_blocked: true).reject { |a| a.iri == reply.iri }
                if !ancestors.empty? && ancestors.all? { |ancestor| [ancestor.to, ancestor.cc].compact.flatten.includes?(recipient) }
                  Relationship::Social::Follow.where(
                    object: receiver,
                    confirmed: true,
                  ).select(&.actor?).map(&.actor.iri)
                end
              end
            end
          end
        elsif (sender = activity.actor?)
          # 3. receiver is a follower of the sender and the recipient
          # is either the public collection or the sender's followers
          # collection. replace with the receiver.
          if receiver.follows?(sender, confirmed: true)
            if recipient == Ktistec::Constants::PUBLIC
              receiver.iri
            elsif recipient && recipient == sender.followers
              receiver.iri
            end
          end
        end
      end.compact.sort!.uniq!
    end
  end
end
