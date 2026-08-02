require "../ktistec/constants"
require "../models/account"
require "../models/activity_pub/activity"
require "../models/activity_pub/activity/accept"
require "../models/activity_pub/activity/dislike"
require "../models/activity_pub/activity/follow"
require "../models/activity_pub/activity/like"
require "../models/activity_pub/activity/quote_request"
require "../models/activity_pub/activity/reject"
require "../models/activity_pub/actor"
require "../models/activity_pub/object"
require "../models/relationship/social/follow"

module Ktistec
  # Recipient expansion and partitioning shared by tasks and
  # processors.
  #
  module Recipients
    record Partition,
      local : Array({ActivityPub::Actor, Account}),
      remote : Array(String)

    # Expands an outbound activity's recipient fields into a sorted,
    # deduplicated list of actor IRIs reachable from this server.
    #
    # The sender is never included in the output -- actors don't
    # deliver to themselves.
    #
    def self.for_deliver(activity : ActivityPub::Activity, sender : ActivityPub::Actor) : Array(String)
      [activity.to, activity.cc, activity.audience].flatten.flat_map do |recipient|
        if recipient == sender.iri
          # no-op
        elsif recipient == Ktistec::Constants::PUBLIC
          # no-op
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
      expand(activity, receiver, [activity.to, activity.cc, deliver_to].flatten)
    end

    # Expands addressed IRIs relative to a single receiver.
    #
    private def self.expand(activity : ActivityPub::Activity, receiver : ActivityPub::Actor, recipients : Array(String?)) : Array(String)
      recipients.flat_map do |recipient|
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

    # Returns the local accounts an inbound activity implicates.
    #
    # Recipients come from two sources, unioned: the activity's
    # explicit addressing and the recipient implied by the activity's
    # type.
    #
    def self.local_recipients(activity : ActivityPub::Activity) : Array(Account)
      accounts = Account.all
      recipients = [activity.to, activity.cc, activity.audience].flatten
      iris = Set(String).new
      accounts.each do |account|
        iris.concat(expand(activity, account.actor, recipients))
      end
      if (iri = semantic_recipient_iri?(activity))
        iris << iri
      end
      accounts.select { |account| iris.includes?(account.iri) }
    end

    # Returns the IRI of the actor the activity implicates by virtue of
    # its type, if any.
    #
    # Only IRIs come from the payload; any attribute of the object
    # they name is read from the cache.
    #
    private def self.semantic_recipient_iri?(activity : ActivityPub::Activity) : String?
      case activity
      when ActivityPub::Activity::Follow
        activity.object_iri
      when ActivityPub::Activity::Accept, ActivityPub::Activity::Reject
        if (object_iri = activity.object_iri)
          ActivityPub::Activity.find?(object_iri, include_undone: true).try(&.actor_iri)
        end
      when ActivityPub::Activity::Like, ActivityPub::Activity::Dislike, ActivityPub::Activity::QuoteRequest
        if (object_iri = activity.object_iri)
          ActivityPub::Object.find?(object_iri, include_deleted: true).try(&.attributed_to_iri)
        end
      end
    end

    # Returns true if the receiver is the actor the inbound activity
    # implicates by virtue of its type.
    #
    def self.semantic_recipient?(activity : ActivityPub::Activity, receiver : ActivityPub::Actor) : Bool
      semantic_recipient_iri?(activity) == receiver.iri
    end

    # Returns true if the receiver is a recipient of the inbound
    # activity.
    #
    def self.recipient?(activity : ActivityPub::Activity, receiver : ActivityPub::Actor, deliver_to : Array(String)?) : Bool
      recipients = [activity.to, activity.cc, deliver_to].flatten.compact
      return true if recipients.includes?(receiver.iri)
      if (sender = activity.actor?) && Relationship::Social::Follow.find?(actor: receiver, object: sender, confirmed: true)
        return true if recipients.includes?(Ktistec::Constants::PUBLIC)
        return true if (followers = sender.followers) && recipients.includes?(followers)
      end
      false
    end

    # Splits IRIs into local recipients (paired with their `Account`)
    # and remote recipients.
    #
    # IRIs that don't resolve to a local actor with an account fall
    # through to the remote bucket.
    #
    def self.partition(iris : Enumerable(String)) : Partition
      local = [] of {ActivityPub::Actor, Account}
      remote = [] of String
      iris.each do |iri|
        actor = ActivityPub::Actor.find?(iri)
        if actor && actor.local? && (account = Account.find?(iri: actor.iri))
          local << {actor, account}
        else
          remote << iri
        end
      end
      Partition.new(local, remote)
    end
  end
end
