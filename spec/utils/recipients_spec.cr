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

    it "includes the sender by default" do
      expect(subject).to contain(sender.iri)
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
end
