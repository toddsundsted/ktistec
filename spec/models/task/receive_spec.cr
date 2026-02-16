require "../../../src/models/task/receive"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/network"

Spectator.describe Task::Receive do
  setup_spec

  let(receiver) do
    register.actor
  end

  let_build(:activity)

  context "validation" do
    let!(options) do
      {source_iri: receiver.save.iri, subject_iri: activity.save.iri}
    end

    it "rejects missing receiver" do
      new_relationship = described_class.new(**options.merge({source_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("receiver")
    end

    it "rejects missing activity" do
      new_relationship = described_class.new(**options.merge({subject_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("activity")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe "#deliver_to" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity
      )
    end

    it "retrieves the deliver to value from the state" do
      subject.state = Task::Receive::State.new([] of String)
      expect(subject.deliver_to).to be_a(Array(String))
    end

    it "retrieves the deliver to value from the state" do
      subject.state = Task::Receive::State.new([] of String)
      expect(subject.deliver_to).to be_empty
    end
  end

  describe "#deliver_to=" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity
      )
    end

    it "stores the deliver to value in the state" do
      subject.deliver_to = ["https://recipient"]
      expect(subject.state.deliver_to).to eq(["https://recipient"])
    end
  end

  let_build(:actor, named: :local_recipient, iri: "https://test.test/actors/local")
  let_build(:actor, named: :remote_recipient, iri: "https://remote/actors/remote")

  let_build(:collection, named: :local_collection, iri: "https://test.test/collections/local")
  let_build(:collection, named: :remote_collection, iri: "https://remote/collections/remote")

  describe "#recipients" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity
      )
    end

    it "does not include the receiver by default" do
      expect(subject.recipients).not_to contain(receiver.iri)
    end

    context "addressed to the receiver" do
      let(recipient) { receiver }

      before_each { activity.to = [recipient.iri] }

      it "includes the receiver" do
        expect(subject.recipients).to contain(recipient.iri)
      end
    end

    context "addressed to a local recipient" do
      let(recipient) { local_recipient }

      before_each { activity.to = [recipient.iri] }

      it "does not include the recipient" do
        expect(subject.recipients).not_to contain(recipient.iri)
      end
    end

    context "addressed to a remote recipient" do
      let(recipient) { remote_recipient }

      before_each { activity.to = [recipient.iri] }

      it "does not include the recipient" do
        expect(subject.recipients).not_to contain(recipient.iri)
      end
    end

    context "addressed to a local collection" do
      let(recipient) { local_collection }

      before_each { activity.to = [recipient.iri] }

      it "does not include the collection" do
        expect(subject.recipients).not_to contain(recipient.iri)
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
            expect(subject.recipients).not_to contain(recipient.iri)
          end

          it "does not include the followers" do
            expect(subject.recipients).not_to contain(local_recipient.iri, remote_recipient.iri)
          end

          context "which is addressed to the local collection" do
            before_each do
              original.to = [recipient.iri]
              reply.to = [recipient.iri]
              original.save
              reply.save
            end

            it "includes the followers" do
              expect(subject.recipients).to contain(local_recipient.iri, remote_recipient.iri)
            end

            context "when follows are not confirmed" do
              before_each do
                Relationship::Social::Follow.where(to_iri: receiver.iri).each do |follow|
                  follow.assign(confirmed: false).save
                end
              end

              it "does not include the followers" do
                expect(subject.recipients).not_to contain(local_recipient.iri, remote_recipient.iri)
              end
            end

            context "when followers have been deleted" do
              before_each do
                local_recipient.delete!
                remote_recipient.delete!
              end

              it "does not include the recipients" do
                expect(subject.recipients).not_to contain(local_recipient.iri, remote_recipient.iri)
              end
            end

            context "when the original is not attributed to the receiver" do
              before_each do
                original.assign(attributed_to: remote_recipient).save
              end

              it "does not include the followers" do
                expect(subject.recipients).not_to contain(local_recipient.iri, remote_recipient.iri)
              end

              context "but it is itself a reply to another post by the receiver" do
                let_build(:object, named: :another, attributed_to: receiver, to: [recipient.iri])

                before_each do
                  original.assign(in_reply_to: another).save
                end

                it "includes the followers" do
                  expect(subject.recipients).to contain(local_recipient.iri, remote_recipient.iri)
                end

                context "unless it doesn't address the local colletion" do
                  before_each do
                    original.to = [remote_collection.iri]
                    original.save
                  end

                  it "does not include the followers" do
                    expect(subject.recipients).not_to contain(local_recipient.iri, remote_recipient.iri)
                  end
                end
              end
            end
          end
        end
      end
    end

    context "addressed to a remote collection" do
      let(recipient) { remote_collection }

      before_each { activity.to = [recipient.iri] }

      it "does not include the collection" do
        expect(subject.recipients).not_to contain(recipient.iri)
      end

      it "does not include the receiver" do
        expect(subject.recipients).not_to contain(receiver.iri)
      end

      context "of the senders's followers" do
        let_build(:actor, named: :sender)

        let(recipient) { remote_collection.assign(iri: "#{sender.iri}/followers") }

        before_each do
          activity.actor_iri = sender.iri
          HTTP::Client.collections << recipient
          do_follow(receiver, sender)
        end

        it "includes the receiver" do
          expect(subject.recipients).to contain(receiver.iri)
        end

        context "when collection isn't the followers collection" do
          let(recipient) { remote_collection.assign(iri: "#{sender.iri}/collection") }

          it "does not include the receiver" do
            expect(subject.recipients).not_to contain(receiver.iri)
          end
        end

        context "when follows are not confirmed" do
          before_each do
            Relationship::Social::Follow.where(from_iri: receiver.iri).each do |follow|
              follow.assign(confirmed: false).save
            end
          end

          it "does not include the receiver" do
            expect(subject.recipients).not_to contain(receiver.iri)
          end
        end
      end
    end

    context "addressed to the public collection" do
      PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

      before_each { activity.to = [PUBLIC] }

      it "does not include the collection" do
        expect(subject.recipients).not_to contain(PUBLIC)
      end

      it "does not include the receiver" do
        expect(subject.recipients).not_to contain(receiver.iri)
      end

      context "the receiver is a follower of the sender" do
        let_build(:actor, named: :sender)

        before_each do
          activity.actor_iri = sender.iri
          do_follow(receiver, sender)
        end

        it "includes the receiver" do
          expect(subject.recipients).to contain(receiver.iri)
        end
      end
    end
  end

  describe "#perform" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity
      )
    end

    context "when the object has already been deleted" do
      let_build(:delete, named: :activity, actor_iri: receiver.iri, object_iri: "https://deleted", to: [receiver.iri])

      it "does not fail" do
        expect { subject.perform }.not_to change { subject.failures }
      end
    end

    context "when the activity object is local" do
      let(authorization_iri) { "https://remote/authorizations/#{random_string}" }

      let_create(:object, named: :quote, local: false)
      let_create(:object, named: :post, local: true, quote_iri: quote.iri, quote_authorization_iri: authorization_iri)
      let_build(:create, named: :activity, actor_iri: receiver.iri, object_iri: post.iri, to: [receiver.iri])

      before_each do
        HTTP::Client.objects << quote
        HTTP::Client.actors << quote.attributed_to
      end

      it "does not dereference the quote authorization" do
        subject.perform
        expect(HTTP::Client.requests).not_to have("GET #{authorization_iri}")
      end
    end

    context "when the activity object has a quote" do
      let_build(:object, named: :quote)
      let_create(:object, named: :post, quote_iri: quote.iri)
      let_build(:create, named: :activity, actor_iri: receiver.iri, object_iri: post.iri, to: [receiver.iri])

      before_each do
        HTTP::Client.objects << quote
        HTTP::Client.actors << quote.attributed_to
      end

      it "dereferences the quote" do
        expect { subject.perform }.to change { ActivityPub::Object.find?(iri: quote.iri) }
      end

      it "dereferences the quote's author" do
        expect { subject.perform }.to change { ActivityPub::Actor.find?(iri: quote.attributed_to.iri) }
      end

      context "and the quoted object cannot be fetched" do
        before_each do
          post.assign(quote_iri: "https://remote/objects/missing").save
        end

        it "requests the quoted object" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET https://remote/objects/missing")
        end

        it "does not dereference the quoted object" do
          expect { subject.perform }.not_to change { ActivityPub::Object.find?(iri: "https://remote/objects/missing") }
        end

        it "does not fail" do
          expect { subject.perform }.not_to change { subject.failures }
        end
      end

      context "with a quote_authorization_iri" do
        let(authorization_iri) { "https://remote/authorizations/#{random_string}" }

        before_each do
          post.assign(quote_authorization_iri: authorization_iri).save
        end

        context "and the quote is a self-quote" do
          before_each do
            post.assign(attributed_to_iri: quote.attributed_to_iri).save
          end

          it "does not dereference the quote authorization" do
            subject.perform
            expect(HTTP::Client.requests).not_to have("GET #{authorization_iri}")
          end
        end

        context "and the quote is not a self-quote" do
          let_build(:quote_decision, interacting_object: post, interaction_target: quote)
          let_build(:quote_authorization, quote_decision: quote_decision, attributed_to: quote.attributed_to, iri: authorization_iri)

          before_each do
            HTTP::Client.objects << quote_authorization
          end

          it "dereferences the quote authorization" do
            subject.perform
            expect(HTTP::Client.requests).to have("GET #{authorization_iri}")
          end

          it "saves the quote authorization" do
            expect { subject.perform }.to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
          end

          context "and quote authorization has wrong interacting_object_iri" do
            before_each do
              quote_decision.interacting_object_iri = "https://remote/wrong"
              HTTP::Client.objects << quote_authorization
            end

            it "does not save the quote authorization" do
              expect { subject.perform }.not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end
          end

          context "and quote authorization has wrong interaction_target_iri" do
            before_each do
              quote_decision.interaction_target_iri = "https://remote/wrong"
              HTTP::Client.objects << quote_authorization
            end

            it "does not save the quote authorization" do
              expect { subject.perform }.not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end
          end

          context "and quote authorization has wrong attributed_to_iri" do
            before_each do
              quote_authorization.attributed_to_iri = "https://remote/wrong"
              HTTP::Client.objects << quote_authorization
            end

            it "does not save the quote authorization" do
              expect { subject.perform }.not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end
          end

          context "when quote authorization cannot be dereferenced" do
            before_each do
              HTTP::Client.cache.delete(authorization_iri)
            end

            it "does not save the quote authorization" do
              expect { subject.perform }.not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end

            it "does not fail" do
              expect { subject.perform }.not_to change { subject.failures }
            end
          end
        end
      end
    end
  end
end
