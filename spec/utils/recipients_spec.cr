require "../../src/utils/recipients"

require "../spec_helper/base"
require "../spec_helper/factory"
require "../spec_helper/network"

Spectator.describe Ktistec::Recipients do
  setup_spec

  let(account) { register }
  let(sender) { account.actor }
  let(receiver) { account.actor }

  let_build(:activity)

  let_build(:actor, named: :local_recipient, username: "local", local: true)
  let_build(:actor, named: :remote_recipient, username: "remote")

  let_build(:collection, named: :local_collection, iri: "https://test.test/collections/local")
  let_build(:collection, named: :remote_collection, iri: "https://remote/collections/remote")

  describe ".for_deliver" do
    subject { described_class.for_deliver(activity, sender) }

    it "excludes the sender" do
      activity.to = [sender.iri]
      expect(subject).not_to contain(sender.iri)
    end

    context "addressed to a local recipient" do
      let(recipient) { local_recipient.save }

      before_each { activity.to = [recipient.iri] }

      it "includes the recipient" do
        expect(subject).to contain(recipient.iri)
      end
    end

    context "addressed to a remote recipient" do
      let(recipient) { remote_recipient }

      before_each { activity.to = [recipient.iri] }

      context "that is cached" do
        before_each { recipient.save }

        it "includes the recipient" do
          expect(subject).to contain(recipient.iri)
        end
      end

      context "that is not cached" do
        before_each { HTTP::Client.actors << recipient }

        it "does not include the recipient" do
          expect(subject).not_to contain(recipient.iri)
        end

        it "does not dereference the recipient" do
          subject
          expect(HTTP::Client.requests).to be_empty
        end
      end
    end

    context "addressed to a local collection" do
      let(recipient) { local_collection }

      before_each { activity.to = [recipient.iri] }

      it "does not include the collection" do
        expect(subject).not_to contain(recipient.iri)
      end

      context "of the sender's followers" do
        let(recipient) { local_collection.assign(iri: "#{sender.iri}/followers") }

        before_each do
          do_follow(local_recipient, sender)
          do_follow(remote_recipient, sender)
        end

        it "does not include the collection" do
          expect(subject).not_to contain(recipient.iri)
        end

        it "includes the followers" do
          expect(subject).to contain(local_recipient.iri, remote_recipient.iri)
        end

        context "when follows are not confirmed" do
          before_each do
            Relationship::Social::Follow.where(to_iri: sender.iri).each do |follow|
              follow.assign(confirmed: false).save
            end
          end

          it "does not include the followers" do
            expect(subject).not_to contain(local_recipient.iri, remote_recipient.iri)
          end
        end

        context "when followers have been deleted" do
          before_each do
            local_recipient.delete!
            remote_recipient.delete!
          end

          it "does not include the recipients" do
            expect(subject).not_to contain(local_recipient.iri, remote_recipient.iri)
          end
        end
      end
    end

    context "audience addressed to a remote group" do
      let(group) { remote_recipient }

      before_each { activity.audience = [group.iri] }

      context "that is cached" do
        before_each { group.save }

        it "includes the group" do
          expect(subject).to contain(group.iri)
        end
      end
    end

    context "audience addressed to remote groups" do
      let(spam_iris) { (1..50).map { |i| "https://attacker.example/actor/#{i}" } }

      before_each { activity.audience = spam_iris }

      it "does not dereference them" do
        subject
        expect(HTTP::Client.requests).to be_empty
      end

      it "drops them" do
        expect(subject).not_to have_elements(spam_iris)
      end
    end

    context "addressed to a remote collection" do
      let(recipient) { remote_collection }

      before_each { activity.to = [recipient.iri] }

      it "does not include the collection" do
        expect(subject).not_to contain(recipient.iri)
      end
    end

    context "addressed to the public collection" do
      before_each { activity.to = [Ktistec::Constants::PUBLIC] }

      it "does not include the collection" do
        expect(subject).not_to contain(Ktistec::Constants::PUBLIC)
      end
    end
  end

  describe ".for_receive" do
    let(deliver_to) { nil }

    subject { described_class.for_receive(activity, receiver, deliver_to) }

    it "does not include the receiver by default" do
      expect(subject).not_to contain(receiver.iri)
    end

    context "addressed to the receiver" do
      before_each { activity.to = [receiver.iri] }

      it "includes the receiver" do
        expect(subject).to contain(receiver.iri)
      end
    end

    context "addressed to a local recipient" do
      before_each { activity.to = [local_recipient.iri] }

      it "does not include the recipient" do
        expect(subject).not_to contain(local_recipient.iri)
      end
    end

    context "addressed to a remote recipient" do
      before_each { activity.to = [remote_recipient.iri] }

      it "does not include the recipient" do
        expect(subject).not_to contain(remote_recipient.iri)
      end
    end

    context "addressed to a local collection" do
      let(recipient) { local_collection }

      before_each { activity.to = [recipient.iri] }

      it "does not include the collection" do
        expect(subject).not_to contain(recipient.iri)
      end

      context "of the receiver's followers" do
        let(recipient) { local_collection.assign(iri: "#{receiver.iri}/followers") }

        before_each do
          do_follow(local_recipient, receiver)
          do_follow(remote_recipient, receiver)
        end

        context "given a reply" do
          let_build(:object, named: :original, attributed_to: receiver)
          let_build(:object, named: :reply, in_reply_to: original)

          before_each do
            activity.object_iri = reply.iri
            original.save
            reply.save
          end

          it "does not include the collection" do
            expect(subject).not_to contain(recipient.iri)
          end

          it "does not include the followers" do
            expect(subject).not_to contain(local_recipient.iri, remote_recipient.iri)
          end

          context "which is addressed to the local collection" do
            before_each do
              original.to = [recipient.iri]
              reply.to = [recipient.iri]
              original.save
              reply.save
            end

            it "includes the followers" do
              expect(subject).to contain(local_recipient.iri, remote_recipient.iri)
            end

            it "does not make any network requests" do
              subject
              expect(HTTP::Client.requests).to be_empty
            end

            context "when follows are not confirmed" do
              before_each do
                Relationship::Social::Follow.where(to_iri: receiver.iri).each do |follow|
                  follow.assign(confirmed: false).save
                end
              end

              it "does not include the followers" do
                expect(subject).not_to contain(local_recipient.iri, remote_recipient.iri)
              end
            end

            context "when followers have been deleted" do
              before_each do
                local_recipient.delete!
                remote_recipient.delete!
              end

              it "does not include the recipients" do
                expect(subject).not_to contain(local_recipient.iri, remote_recipient.iri)
              end
            end

            context "when the original is not attributed to the receiver" do
              before_each do
                original.assign(attributed_to: remote_recipient).save
              end

              it "does not include the followers" do
                expect(subject).not_to contain(local_recipient.iri, remote_recipient.iri)
              end

              context "but it is itself a reply to another post by the receiver" do
                let_build(:object, named: :another, attributed_to: receiver, to: [recipient.iri])

                before_each do
                  original.assign(in_reply_to: another).save
                end

                it "includes the followers" do
                  expect(subject).to contain(local_recipient.iri, remote_recipient.iri)
                end

                context "unless it doesn't address the local collection" do
                  before_each do
                    original.to = [remote_collection.iri]
                    original.save
                  end

                  it "does not include the followers" do
                    expect(subject).not_to contain(local_recipient.iri, remote_recipient.iri)
                  end
                end
              end
            end
          end
        end

        context "given a non-reply by the receiver" do
          let_build(:object, named: :non_reply, attributed_to: receiver, to: [recipient.iri])

          before_each do
            activity.object_iri = non_reply.iri
            non_reply.save
          end

          it "does not include the followers" do
            expect(subject).not_to contain(local_recipient.iri, remote_recipient.iri)
          end
        end
      end
    end

    context "addressed to a remote collection" do
      let(recipient) { remote_collection }

      before_each { activity.to = [recipient.iri] }

      it "does not include the collection" do
        expect(subject).not_to contain(recipient.iri)
      end

      it "does not include the receiver" do
        expect(subject).not_to contain(receiver.iri)
      end

      context "of the sender's followers" do
        let_build(:actor, named: :sender_actor)

        let(recipient) { remote_collection.assign(iri: "#{sender_actor.iri}/followers") }

        before_each do
          activity.actor_iri = sender_actor.iri
          do_follow(receiver, sender_actor)
        end

        it "includes the receiver" do
          expect(subject).to contain(receiver.iri)
        end

        it "does not make any network requests" do
          subject
          expect(HTTP::Client.requests).to be_empty
        end

        context "when collection isn't the followers collection" do
          let(recipient) { remote_collection.assign(iri: "#{sender_actor.iri}/collection") }

          it "does not include the receiver" do
            expect(subject).not_to contain(receiver.iri)
          end
        end

        context "when follows are not confirmed" do
          before_each do
            Relationship::Social::Follow.where(from_iri: receiver.iri).each do |follow|
              follow.assign(confirmed: false).save
            end
          end

          it "does not include the receiver" do
            expect(subject).not_to contain(receiver.iri)
          end
        end
      end
    end

    context "addressed to the public collection" do
      before_each { activity.to = [Ktistec::Constants::PUBLIC] }

      it "does not include the collection" do
        expect(subject).not_to contain(Ktistec::Constants::PUBLIC)
      end

      it "does not include the receiver" do
        expect(subject).not_to contain(receiver.iri)
      end

      context "the receiver is a follower of the sender" do
        let_build(:actor, named: :sender_actor)

        before_each do
          activity.actor_iri = sender_actor.iri
          do_follow(receiver, sender_actor)
        end

        it "includes the receiver" do
          expect(subject).to contain(receiver.iri)
        end
      end
    end

    context "given values in deliver_to" do
      let(deliver_to) { [receiver.iri] }

      it "treats them like to/cc recipients" do
        expect(subject).to contain(receiver.iri)
      end
    end
  end

  describe ".local_recipients" do
    subject { described_class.local_recipients(activity) }

    let(iris) { subject.map(&.iri) }

    let!(addressee) { register }
    let!(bystander) { register }

    let_build(:actor, named: :sender_actor)

    before_each { activity.actor_iri = sender_actor.iri }

    it "returns nothing" do
      expect(subject).to be_empty
    end

    context "addressed to an account via to" do
      before_each { activity.to = [addressee.actor.iri] }

      it "includes the account" do
        expect(iris).to contain(addressee.iri)
      end

      it "does not include the other account" do
        expect(iris).not_to contain(bystander.iri)
      end
    end

    context "addressed to an account via cc" do
      before_each { activity.cc = [addressee.actor.iri] }

      it "includes the account" do
        expect(iris).to contain(addressee.iri)
      end

      it "does not include the other account" do
        expect(iris).not_to contain(bystander.iri)
      end
    end

    context "addressed to an account via audience" do
      before_each { activity.audience = [addressee.actor.iri] }

      it "includes the account" do
        expect(iris).to contain(addressee.iri)
      end

      it "does not include the other account" do
        expect(iris).not_to contain(bystander.iri)
      end
    end

    context "addressed to a remote actor" do
      before_each { activity.to = [remote_recipient.iri] }

      it "returns nothing" do
        expect(subject).to be_empty
      end
    end

    context "addressed to the public collection" do
      before_each { activity.to = [Ktistec::Constants::PUBLIC] }

      it "returns nothing" do
        expect(subject).to be_empty
      end

      context "and an account follows the sender" do
        let_create!(:follow_relationship, actor: addressee.actor, object: sender_actor, confirmed: true)

        it "includes the follower" do
          expect(iris).to contain(addressee.iri)
        end

        it "does not include the other account" do
          expect(iris).not_to contain(bystander.iri)
        end

        context "but the follow is not confirmed" do
          before_each { follow_relationship.assign(confirmed: false).save }

          it "returns nothing" do
            expect(subject).to be_empty
          end
        end
      end
    end

    context "addressed to the sender's followers collection" do
      before_each { activity.to = ["#{sender_actor.iri}/followers"] }

      it "returns nothing" do
        expect(subject).to be_empty
      end

      context "and an account follows the sender" do
        let_create!(:follow_relationship, actor: addressee.actor, object: sender_actor, confirmed: true)

        it "includes the follower" do
          expect(iris).to contain(addressee.iri)
        end

        it "does not include the other account" do
          expect(iris).not_to contain(bystander.iri)
        end

        context "but the follow is not confirmed" do
          before_each { follow_relationship.assign(confirmed: false).save }

          it "returns nothing" do
            expect(subject).to be_empty
          end
        end
      end
    end

    context "addressed to an account's followers collection" do
      let!(collection_owner) { register }
      let!(follower) { register }

      before_each { activity.to = ["#{collection_owner.actor.iri}/followers"] }

      let_create!(:follow_relationship, actor: follower.actor, object: collection_owner.actor, confirmed: true)

      it "returns nothing" do
        expect(subject).to be_empty
      end

      context "and the activity's object is a reply in a thread the owner started" do
        let_build(:object, named: :original, attributed_to: collection_owner.actor, to: ["#{collection_owner.actor.iri}/followers"])
        let_build(:object, named: :reply, in_reply_to: original)

        before_each do
          original.save
          reply.save
          activity.object_iri = reply.iri
        end

        it "includes the follower" do
          expect(iris).to contain(follower.iri)
        end

        it "does not include the owner" do
          expect(iris).not_to contain(collection_owner.iri)
        end
      end
    end

    context "given a Follow of an account's actor" do
      let_build(:follow, named: :activity, actor: sender_actor, object: addressee.actor)

      it "includes the account" do
        expect(iris).to contain(addressee.iri)
      end

      context "of a remote actor" do
        let_build(:follow, named: :activity, actor: sender_actor, object: remote_recipient)

        it "returns nothing" do
          expect(subject).to be_empty
        end
      end
    end

    context "given an Accept of an account's Follow" do
      let_create!(:follow, named: :follow_activity, actor: addressee.actor, object: sender_actor)
      let_build(:accept, named: :activity, actor: sender_actor, object: follow_activity)

      it "includes the account" do
        expect(iris).to contain(addressee.iri)
      end

      context "when this server never sent the Follow" do
        let_build(:follow, named: :follow_activity, actor: addressee.actor, object: sender_actor)

        it "returns nothing" do
          expect(subject).to be_empty
        end
      end
    end

    context "given a Reject of an account's Follow" do
      let_create!(:follow, named: :follow_activity, actor: addressee.actor, object: sender_actor)
      let_build(:reject, named: :activity, actor: sender_actor, object: follow_activity)

      it "includes the account" do
        expect(iris).to contain(addressee.iri)
      end

      context "when this server never sent the Follow" do
        let_build(:follow, named: :follow_activity, actor: addressee.actor, object: sender_actor)

        it "returns nothing" do
          expect(subject).to be_empty
        end
      end
    end

    context "given an account's cached object" do
      let_create!(:object, named: :owned, attributed_to: addressee.actor)

      # `to: nil` throughout -- the like/dislike factories otherwise
      # address the activity to the object's owner, which would
      # exercise explicit addressing rather than the semantic path.

      context "and a Like" do
        let_build(:like, named: :activity, actor: sender_actor, object: owned, to: nil)

        it "includes the account" do
          expect(iris).to contain(addressee.iri)
        end

        context "when the payload names an object this server doesn't have" do
          let_build(:object, named: :owned, attributed_to: addressee.actor)

          it "returns nothing" do
            expect(subject).to be_empty
          end
        end

        context "when the payload claims a different owner" do
          let_build(:object, named: :forged, iri: owned.iri, attributed_to: bystander.actor)
          let_build(:like, named: :activity, actor: sender_actor, object: forged, to: nil)

          it "includes the stored owner" do
            expect(iris).to contain(addressee.iri)
          end

          it "does not include the claimed owner" do
            expect(iris).not_to contain(bystander.iri)
          end
        end
      end

      context "and a Like addressed to another account" do
        let_build(:like, named: :activity, actor: sender_actor, object: owned, to: [bystander.actor.iri])

        it "includes both accounts" do
          expect(iris).to contain_exactly(addressee.iri, bystander.iri)
        end
      end

      context "and a Dislike" do
        let_build(:dislike, named: :activity, actor: sender_actor, object: owned, to: nil)

        it "includes the account" do
          expect(iris).to contain(addressee.iri)
        end
      end

      context "and a QuoteRequest for it" do
        let_build(:quote_request, named: :activity, actor: sender_actor, object: owned)

        it "includes the account" do
          expect(iris).to contain(addressee.iri)
        end
      end

      context "and a Delete" do
        let_build(:delete, named: :activity, actor: sender_actor, object: owned)

        it "returns nothing" do
          expect(subject).to be_empty
        end
      end

      context "and an Undo of a Like" do
        let_create!(:like, named: :like_activity, actor: sender_actor, object: owned, to: nil)
        let_build(:undo, named: :activity, actor: sender_actor, activity: like_activity)

        it "returns nothing" do
          expect(subject).to be_empty
        end
      end
    end
  end

  describe ".forwarding" do
    let!(collection_owner) { register }

    let_build(:actor, named: :sender_actor)

    subject { described_class.forwarding(activity) }

    before_each { activity.actor_iri = sender_actor.save.iri }

    it "returns nothing" do
      expect(subject).to be_nil
    end

    context "addressed to an account's followers collection" do
      let_create!(:actor, named: :remote_follower)
      let_create!(:follow_relationship, actor: remote_follower, object: collection_owner.actor, confirmed: true)

      before_each { activity.to = ["#{collection_owner.actor.iri}/followers"] }

      it "returns nothing" do
        expect(subject).to be_nil
      end

      context "when the activity's object is a reply in a thread the owner started" do
        let_build(:object, named: :origin, attributed_to: collection_owner.actor, to: ["#{collection_owner.actor.iri}/followers"])
        let_build(:object, named: :reply, in_reply_to: origin)

        before_each do
          origin.save
          reply.save
          activity.object_iri = reply.iri
        end

        it "returns the collection's owner" do
          expect(subject.try(&.account)).to eq(collection_owner)
        end

        it "returns the owner's followers" do
          expect(subject.try(&.recipients)).to eq([remote_follower.iri])
        end

        context "and a follower is local" do
          let!(local_follower) { register }
          let_create!(:follow_relationship, named: :local_relationship, actor: local_follower.actor, object: collection_owner.actor, confirmed: true)

          it "does not return the local follower" do
            expect(subject.try(&.recipients)).not_to contain(local_follower.iri)
          end
        end

        context "and the follow is not confirmed" do
          before_each { follow_relationship.assign(confirmed: false).save }

          it "returns nothing" do
            expect(subject).to be_nil
          end
        end

        context "and the collection is addressed via audience" do
          before_each do
            activity.to = nil
            activity.audience = ["#{collection_owner.actor.iri}/followers"]
          end

          it "returns nothing" do
            expect(subject).to be_nil
          end
        end
      end
    end
  end

  describe ".recipient?" do
    let(deliver_to) { nil }

    let_build(:actor, named: :sender_actor)

    before_each { activity.actor_iri = sender_actor.save.iri }

    subject { described_class.recipient?(activity, receiver, deliver_to) }

    it "rejects an activity" do
      expect(subject).to be_false
    end

    context "addressed to the receiver via to" do
      before_each { activity.to = [receiver.iri] }

      it "accepts the activity" do
        expect(subject).to be_true
      end
    end

    context "addressed to the receiver via cc" do
      before_each { activity.cc = [receiver.iri] }

      it "accepts the activity" do
        expect(subject).to be_true
      end
    end

    context "delivered to the receiver via deliver_to" do
      let(deliver_to) { [receiver.iri] }

      it "accepts the activity" do
        expect(subject).to be_true
      end
    end

    context "addressed to the public collection" do
      before_each { activity.to = [Ktistec::Constants::PUBLIC] }

      it "rejects the activity" do
        expect(subject).to be_false
      end

      context "and the receiver follows the sender" do
        before_each { do_follow(receiver, sender_actor) }

        it "accepts the activity" do
          expect(subject).to be_true
        end
      end

      context "but the follow is not confirmed" do
        before_each { do_follow(receiver, sender_actor).assign(confirmed: false).save }

        it "rejects the activity" do
          expect(subject).to be_false
        end
      end
    end

    context "addressed to the sender's followers collection" do
      before_each { activity.to = ["#{sender_actor.iri}/followers"] }

      it "rejects the activity" do
        expect(subject).to be_false
      end

      context "and the receiver follows the sender" do
        before_each { do_follow(receiver, sender_actor) }

        it "accepts the activity" do
          expect(subject).to be_true
        end
      end
    end
  end

  describe ".partition" do
    subject { described_class.partition(iris) }

    context "given a local actor's IRI" do
      let(iris) { [sender.iri] }

      it "pairs the actor with its account" do
        expect(subject.local).to eq([{sender, account}])
      end

      it "leaves the remote list empty" do
        expect(subject.remote).to be_empty
      end
    end

    context "given a remote actor's IRI" do
      let(iris) { [remote_recipient.save.iri] }

      it "puts the IRI in the remote list" do
        expect(subject.remote).to eq([remote_recipient.iri])
      end

      it "leaves the local list empty" do
        expect(subject.local).to be_empty
      end
    end

    context "given an unknown IRI" do
      let(iris) { ["https://unknown.example/actor/missing"] }

      it "puts the IRI in the remote list" do
        expect(subject.remote).to eq(iris)
      end

      it "leaves the local list empty" do
        expect(subject.local).to be_empty
      end
    end

    # a saved local actor always has an account. this pins the
    # fallback behavior in case that invariant is ever violated.

    context "given a local actor with no account" do
      let(iris) { [local_recipient.save.iri] }

      it "puts the IRI in the remote list" do
        expect(subject.remote).to eq([local_recipient.iri])
      end

      it "leaves the local list empty" do
        expect(subject.local).to be_empty
      end
    end

    context "given a mixed list" do
      let(iris) { [sender.iri, remote_recipient.save.iri] }

      it "splits each IRI into its bucket" do
        expect(subject.local).to eq([{sender, account}])
        expect(subject.remote).to eq([remote_recipient.iri])
      end
    end

    context "given an empty list" do
      let(iris) { [] of String }

      it "returns empty buckets" do
        expect(subject.local).to be_empty
        expect(subject.remote).to be_empty
      end
    end
  end
end
