require "../../src/services/inbox_activity_processor"
require "../../src/models/activity_pub/activity/follow"
require "../../src/models/activity_pub/activity/accept"
require "../../src/models/activity_pub/activity/reject"
require "../../src/models/activity_pub/activity/undo"
require "../../src/models/activity_pub/activity/delete"
require "../../src/models/activity_pub/activity/announce"
require "../../src/models/activity_pub/activity/create"
require "../../src/models/activity_pub/activity/quote_request"
require "../../src/models/relationship/social/follow"
require "../../src/models/task/deliver_delayed_object"

require "../spec_helper/base"
require "../spec_helper/factory"
require "../spec_helper/mock"
require "../spec_helper/network"

Spectator.describe InboxActivityProcessor do
  setup_spec

  let(account) { register }
  let_create(:actor, named: :other)
  let_create(:object, attributed_to: other)

  before_each do
    MockHandleFollowRequestTask.reset!
    MockReceiveTask.reset!
    MockDeliverTask.reset!
  end

  describe ".process" do
    context "given a filter term" do
      let_create!(:filter_term, actor: account.actor, term: "%content%")

      before_each do
        object.assign(content: "<span class='capitalize'>c</span>ontent blah blah").save
      end

      context "and a matching Create from a remote actor" do
        let_create!(:create, named: :filtered_create, actor: other, object: object, to: [account.actor.iri])

        it "does not store the activity in the recipient's inbox" do
          InboxActivityProcessor.process(account, filtered_create, receive_task_class: MockReceiveTask)
          expect(account.actor.in_inbox(public: false)).to be_empty
        end
      end

      context "and a matching Announce from a remote actor" do
        let_create!(:announce, named: :filtered_announce, actor: other, object: object, to: [account.actor.iri])

        it "does not store the activity in the recipient's inbox" do
          InboxActivityProcessor.process(account, filtered_announce, receive_task_class: MockReceiveTask)
          expect(account.actor.in_inbox(public: false)).to be_empty
        end
      end

      context "and a matching Create by the author" do
        let_create!(:object, attributed_to: account.actor)
        let_create!(:create, named: :filtered_create, actor: account.actor, object: object, to: [account.actor.iri])

        before_each do
          object.assign(content: "<span class='capitalize'>c</span>ontent blah blah").save
        end

        it "stores the activity in the recipient's inbox" do
          InboxActivityProcessor.process(account, filtered_create, receive_task_class: MockReceiveTask)
          expect(account.actor.in_inbox(public: false)).to eq([filtered_create])
        end
      end
    end

    context "with a Create addressed to the recipient" do
      let_create!(:create, named: :addressed_create, actor: other, object: object, to: [account.actor.iri])

      it "stores the activity in the recipient's inbox" do
        InboxActivityProcessor.process(account, addressed_create, receive_task_class: MockReceiveTask)
        expect(account.actor.in_inbox(public: false)).to eq([addressed_create])
      end

      context "given an existing inbox item" do
        before_each { put_in_inbox(account.actor, addressed_create) }

        it "does not store a duplicate" do
          expect { InboxActivityProcessor.process(account, addressed_create, receive_task_class: MockReceiveTask) }
            .not_to change { Relationship::Content::Inbox.count(owner: account.actor, activity: addressed_create) }
        end
      end
    end

    context "with a Create not addressed to the recipient" do
      let_create!(:create, named: :unaddressed_create, actor: other, object: object)

      it "does not store the activity in the recipient's inbox" do
        InboxActivityProcessor.process(account, unaddressed_create, receive_task_class: MockReceiveTask)
        expect(account.actor.in_inbox(public: false)).to be_empty
      end
    end

    context "with a Follow activity" do
      let_create(:follow, named: :follow_activity, actor: other, object: account.actor)

      it "creates a follow relationship" do
        expect { InboxActivityProcessor.process(account, follow_activity) }
          .to change { Relationship::Social::Follow.count }.by(1)
      end

      context "given another actor" do
        let_build(:actor, named: other_actor)

        before_each { follow_activity.assign(object: other_actor).save }

        it "does not create a follow relationship" do
          expect { InboxActivityProcessor.process(account, follow_activity) }
            .not_to change { Relationship::Social::Follow.count }
        end
      end

      it "sets the relationship as unconfirmed" do
        InboxActivityProcessor.process(account, follow_activity)
        follow = Relationship::Social::Follow.find?(actor: other, object: account.actor)
        expect(follow.try(&.confirmed)).to be_false
      end

      it "schedules handle follow request task" do
        InboxActivityProcessor.process(account, follow_activity, handle_follow_request_task_class: MockHandleFollowRequestTask)
        expect(MockHandleFollowRequestTask.schedule_called_count).to eq(1)
        expect(MockHandleFollowRequestTask.last_recipient).to eq(account.actor)
        expect(MockHandleFollowRequestTask.last_activity).to eq(follow_activity)
      end

      context "given an additional recipient" do
        let(other_account) { register }

        it "schedules the task only for the followed account" do
          InboxActivityProcessor.process(account, follow_activity, recipients: [account, other_account], handle_follow_request_task_class: MockHandleFollowRequestTask)
          expect(MockHandleFollowRequestTask.schedule_called_count).to eq(1)
          expect(MockHandleFollowRequestTask.last_recipient).to eq(account.actor)
        end
      end

      it "schedules receive task" do
        InboxActivityProcessor.process(account, follow_activity, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(follow_activity)
      end

      context "given an existing relationship" do
        let_create!(:follow_relationship, actor: other, object: account.actor, visible: false)

        it "does not create a duplicate relationship" do
          expect { InboxActivityProcessor.process(account, follow_activity) }
            .not_to change { Relationship::Social::Follow.count }
        end
      end
    end

    let(state) do
      Task::DeliverDelayedObject::State.new(
        Task::DeliverDelayedObject::State::Reason::PendingQuoteAuthorization,
        Task::DeliverDelayedObject::State::PendingQuoteAuthorizationContext.new("https://remote/activities/qr1"),
      )
    end

    context "with an Accept activity" do
      context "for a Follow" do
        let_create(:follow, named: :follow_activity, actor: account.actor, object: other)
        let_create(:follow_relationship, actor: account.actor, object: other, confirmed: false)
        let_create(:accept, named: :accept_activity, actor: other, object: follow_activity)

        it "confirms the follow relationship" do
          expect { InboxActivityProcessor.process(account, accept_activity) }
            .to change { follow_relationship.reload!.confirmed }.from(false).to(true)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, accept_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(accept_activity)
        end
      end

      context "for a QuoteRequest" do
        let(authorization_iri) { "https://remote/authorizations/#{random_string}" }

        let_create(:note, named: :quoted_post, attributed_to: other)
        let_create(:note, named: :quote_post, published: nil, attributed_to: account.actor, local: true)
        let_create(:quote_request, named: :quote_request_activity, actor: account.actor, object: quoted_post, instrument: quote_post)
        let_create(:accept, named: :accept_activity, actor: other, object: quote_request_activity, result_iri: authorization_iri)
        let_create!(:deliver_delayed_object_task, actor: account.actor, object: quote_post, state: state)

        it "schedules receive task" do
          InboxActivityProcessor.process(account, accept_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(accept_activity)
        end

        context "when the quote post cannot be found" do
          before_each { quote_post.destroy }

          it "does not raise an error" do
            expect { InboxActivityProcessor.process(account, accept_activity) }.not_to raise_error
          end
        end

        context "with a QuoteAuthorization" do
          before_each { quote_post.assign(quote_iri: quoted_post.iri).save }

          let_build(:quote_decision, interacting_object: quote_post, interaction_target: quoted_post)
          let_build(:quote_authorization, quote_decision: quote_decision, attributed_to: other, iri: authorization_iri)

          before_each { HTTP::Client.objects << quote_authorization }

          it "dereferences the quote authorization" do
            InboxActivityProcessor.process(account, accept_activity)
            expect(HTTP::Client.requests).to have("GET #{authorization_iri}")
          end

          context "given a recipient who does not own the quote post" do
            let(other_account) { register }

            it "does not dereference the quote authorization" do
              InboxActivityProcessor.process(account, accept_activity, recipients: [other_account])
              expect(HTTP::Client.requests).not_to have("GET #{authorization_iri}")
            end
          end

          it "saves the quote authorization" do
            expect { InboxActivityProcessor.process(account, accept_activity) }
              .to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
          end

          it "sets quote_authorization_iri" do
            InboxActivityProcessor.process(account, accept_activity)
            expect(quote_post.reload!.quote_authorization_iri).to eq(authorization_iri)
          end

          it "publishes the quote post" do
            expect { InboxActivityProcessor.process(account, accept_activity) }
              .to change { quote_post.reload!.published }.from(nil)
          end

          context "and quote authorization has wrong interacting_object_iri" do
            before_each do
              quote_decision.interacting_object_iri = "https://remote/objects/wrong"
              HTTP::Client.objects << quote_authorization
            end

            it "does not save the quote authorization" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end

            it "does not set quote_authorization_iri" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { quote_post.reload!.quote_authorization_iri }
            end

            it "does not publish the quote post" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { quote_post.reload!.published }
            end
          end

          context "and quote authorization has wrong interaction_target_iri" do
            before_each do
              quote_decision.interaction_target_iri = "https://remote/objects/wrong"
              HTTP::Client.objects << quote_authorization
            end

            it "does not save the quote authorization" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end
          end

          context "and quote authorization has wrong attributed_to_iri" do
            before_each do
              quote_authorization.attributed_to_iri = "https://remote/wrong"
              HTTP::Client.objects << quote_authorization
            end

            it "does not save the quote authorization" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end
          end

          context "when QuoteAuthorization cannot be dereferenced" do
            before_each { HTTP::Client.cache.delete(authorization_iri) }

            it "does not save the quote authorization" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end

            it "does not set quote_authorization_iri" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { quote_post.reload!.quote_authorization_iri }
            end

            it "does not publish the quote post" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { quote_post.reload!.published }
            end

            it "does not raise an error" do
              expect { InboxActivityProcessor.process(account, accept_activity) }.not_to raise_error
            end
          end

          context "and the quoted post has been deleted" do
            before_each { quoted_post.destroy }

            it "does not save the quote authorization" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end

            it "does not set quote_authorization_iri" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { quote_post.reload!.quote_authorization_iri }
            end

            it "does not publish the quote post" do
              expect { InboxActivityProcessor.process(account, accept_activity) }
                .not_to change { quote_post.reload!.published }
            end
          end

          context "and the accept is from an actor other than the quoted post's author" do
            let_create(:actor, named: :attacker)
            let_create(:accept, named: :forged_accept, actor: attacker, object: quote_request_activity, result_iri: authorization_iri)

            pre_condition { expect(quoted_post.attributed_to).not_to eq(attacker) }

            it "does not save the quote authorization" do
              expect { InboxActivityProcessor.process(account, forged_accept) }
                .not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end

            it "does not set quote_authorization_iri" do
              expect { InboxActivityProcessor.process(account, forged_accept) }
                .not_to change { quote_post.reload!.quote_authorization_iri }
            end

            it "does not publish the quote post" do
              expect { InboxActivityProcessor.process(account, forged_accept) }
                .not_to change { quote_post.reload!.published }
            end
          end
        end
      end
    end

    context "with a Reject activity" do
      context "for a Follow" do
        let_create(:follow, named: :follow_activity, actor: account.actor, object: other)
        let_create(:follow_relationship, actor: account.actor, object: other, confirmed: false)
        let_create(:reject, named: :reject_activity, actor: other, object: follow_activity)

        it "confirms the follow relationship" do
          expect { InboxActivityProcessor.process(account, reject_activity) }
            .to change { follow_relationship.reload!.confirmed }.from(false).to(true)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, reject_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(reject_activity)
        end
      end

      context "for a QuoteRequest" do
        let_create(:note, named: :quoted_post, attributed_to: other)
        let_create(:note, named: :quote_post, published: nil, attributed_to: account.actor, local: true)
        let_create(:quote_request, named: :quote_request_activity, actor: account.actor, object: quoted_post, instrument: quote_post)
        let_create(:reject, named: :reject_activity, actor: other, object: quote_request_activity)
        let_create!(:deliver_delayed_object_task, actor: account.actor, object: quote_post, state: state)

        it "does not set quote_authorization_iri" do
          InboxActivityProcessor.process(account, reject_activity)
          expect(quote_post.reload!.quote_authorization_iri).to be_nil
        end

        it "does not publish the quote post" do
          expect { InboxActivityProcessor.process(account, reject_activity) }
            .not_to change { quote_post.reload!.published }
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, reject_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(reject_activity)
        end
      end
    end

    context "with an Undo activity" do
      context "given a Follow" do
        let_create(:follow, named: :follow_activity, actor: other, object: account.actor)
        let_create!(:follow_relationship, actor: other, object: account.actor)
        let_create(:undo, named: :undo_activity, actor: other, object: follow_activity)

        pre_condition { expect(follow_relationship).not_to be_nil }

        it "destroys the follow relationship" do
          expect { InboxActivityProcessor.process(account, undo_activity) }
            .to change { Relationship::Social::Follow.count }.by(-1)
        end

        it "marks the follow activity as undone" do
          expect { InboxActivityProcessor.process(account, undo_activity) }
            .to change { follow_activity.reload!.undone_at }.from(nil)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, undo_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(undo_activity)
        end

        context "and the follow activity is already undone" do
          before_each { ActivityPub::Activity::Follow.find(follow_activity.iri).undo! }

          pre_condition { expect(undo_activity.object.undone_at).to be_nil }

          it "leaves the follow relationship alone" do
            InboxActivityProcessor.process(account, undo_activity)
            expect(Relationship::Social::Follow.find?(actor: other, object: account.actor)).not_to be_nil
          end

          context "and the undo carries no cached association" do
            let(fetched) { ActivityPub::Activity.find(undo_activity.iri) }

            it "does not raise" do
              expect { InboxActivityProcessor.process(account, fetched) }.not_to raise_error
            end

            it "leaves the follow relationship alone" do
              InboxActivityProcessor.process(account, fetched)
              expect(Relationship::Social::Follow.find?(actor: other, object: account.actor)).not_to be_nil
            end
          end
        end
      end

      context "given an Announce" do
        let_create(:announce, named: :announce_activity, actor: other, object: object)
        let_create(:undo, named: :undo_activity, actor: other, object: announce_activity)

        it "marks the announce activity as undone" do
          expect { InboxActivityProcessor.process(account, undo_activity) }
            .to change { announce_activity.reload!.undone_at }.from(nil)
        end

        context "and the announce activity is already undone" do
          before_each { ActivityPub::Activity::Announce.find(announce_activity.iri).undo! }

          pre_condition { expect(undo_activity.object.undone_at).to be_nil }

          # re-query, don't `reload!`: reloading populates the cached
          # object's timestamp from the DB before the code under test runs
          it "does not move the undo timestamp" do
            expect { InboxActivityProcessor.process(account, undo_activity) }
              .not_to change { ActivityPub::Activity::Announce.find(announce_activity.iri, include_undone: true).undone_at }
          end
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, undo_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(undo_activity)
        end
      end
    end

    context "with a Delete activity" do
      context "given an Object" do
        let_create(:object, named: :object_to_delete, attributed_to: other)
        let_create(:delete, named: :delete_activity, actor: other, object: object_to_delete)

        it "marks the object as deleted" do
          expect { InboxActivityProcessor.process(account, delete_activity) }
            .to change { object_to_delete.reload!.deleted_at }.from(nil)
        end

        context "and the object is already deleted" do
          before_each { ActivityPub::Object.find(object_to_delete.iri).delete! }

          pre_condition { expect(delete_activity.object.deleted_at).to be_nil }

          # re-query, don't `reload!`: reloading populates the cached
          # object's timestamp from the DB before the code under test runs
          it "does not move the deletion timestamp" do
            expect { InboxActivityProcessor.process(account, delete_activity) }
              .not_to change { ActivityPub::Object.find(object_to_delete.iri, include_deleted: true).deleted_at }
          end
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, delete_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(delete_activity)
        end
      end

      context "given an Actor" do
        let_create(:delete, named: :delete_activity, actor: other, object: other)

        it "marks the actor as deleted" do
          expect { InboxActivityProcessor.process(account, delete_activity) }
            .to change { other.reload!.deleted_at }.from(nil)
        end

        context "and the actor is already deleted" do
          before_each { ActivityPub::Actor.find(other.iri).delete! }

          pre_condition { expect(delete_activity.object.deleted_at).to be_nil }

          # re-query, don't `reload!`: reloading populates the cached
          # object's timestamp from the DB before the code under test runs
          it "does not move the deletion timestamp" do
            expect { InboxActivityProcessor.process(account, delete_activity) }
              .not_to change { ActivityPub::Actor.find(other.iri, include_deleted: true).deleted_at }
          end
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, delete_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(delete_activity)
        end
      end
    end

    context "with Create activity" do
      let_create(:create, named: :create_activity, actor: other, object: object)

      it "schedules receive task" do
        InboxActivityProcessor.process(account, create_activity, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(create_activity)
      end
    end

    context "with Announce activity" do
      let_create(:announce, named: :announce_activity, actor: other, object: object)

      it "schedules receive task" do
        InboxActivityProcessor.process(account, announce_activity, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(announce_activity)
      end
    end

    context "with a QuoteRequest activity" do
      let_create(:note, attributed_to: account.actor)
      let_create(:quote_request, named: :quote_request_activity, actor: other, object: note, instrument_iri: "https://remote/objects/123")

      context "when manually_approve_quotes is true" do
        pre_condition { expect(account.manually_approve_quotes).to be_true }

        it "does not create a quote authorization" do
          expect { InboxActivityProcessor.process(account, quote_request_activity) }
            .not_to change { ActivityPub::Object::QuoteAuthorization.count }
        end

        it "does not create a quote decision" do
          expect { InboxActivityProcessor.process(account, quote_request_activity) }
            .not_to change { QuoteDecision.count }
        end

        it "creates a Reject activity" do
          expect { InboxActivityProcessor.process(account, quote_request_activity) }
            .to change { ActivityPub::Activity::Reject.count }.by(1)
          reject = ActivityPub::Activity::Reject.all.last
          expect(reject.actor).to eq(account.actor)
          expect(reject.object?).to eq(quote_request_activity)
          expect(reject.result?).to be_nil
        end

        context "given a recipient who does not own the quoted post" do
          let(other_account) { register }

          it "does not create a Reject activity" do
            expect { InboxActivityProcessor.process(account, quote_request_activity, recipients: [other_account]) }
              .not_to change { ActivityPub::Activity::Reject.count }
          end
        end

        it "schedules deliver task" do
          InboxActivityProcessor.process(account, quote_request_activity, deliver_task_class: MockDeliverTask)
          expect(MockDeliverTask.schedule_called_count).to eq(1)
          expect(MockDeliverTask.last_sender).to eq(account.actor)
          expect(MockDeliverTask.last_activity).to be_a(ActivityPub::Activity::Reject)
        end

        context "and the request has already been rejected" do
          before_each { InboxActivityProcessor.process(account, quote_request_activity) }

          it "does not create a second Reject" do
            expect { InboxActivityProcessor.process(account, quote_request_activity) }
              .not_to change { ActivityPub::Activity::Reject.count }
          end

          it "does not create a second notification" do
            expect { InboxActivityProcessor.process(account, quote_request_activity) }
              .not_to change { Relationship::Content::Notification::Quote.count }
          end

          it "does not schedule a second deliver task" do
            InboxActivityProcessor.process(account, quote_request_activity, deliver_task_class: MockDeliverTask)
            expect(MockDeliverTask.schedule_called_count).to eq(0)
          end
        end
      end

      context "when manually_approve_quotes is false" do
        before_each { account.assign(manually_approve_quotes: false).save }

        it "creates a quote authorization" do
          expect { InboxActivityProcessor.process(account, quote_request_activity) }
            .to change { ActivityPub::Object::QuoteAuthorization.count }.by(1)
          authorization = ActivityPub::Object::QuoteAuthorization.all.last
          expect(authorization.visible).to be_true
        end

        it "creates a quote decision" do
          expect { InboxActivityProcessor.process(account, quote_request_activity) }
            .to change { QuoteDecision.count }.by(1)
          decision = QuoteDecision.where(interaction_target_iri: note.iri, interacting_object_iri: "https://remote/objects/123").first
          expect(decision.decision).to eq("accept")
        end

        it "creates an Accept activity with a QuoteAuthorization" do
          expect { InboxActivityProcessor.process(account, quote_request_activity) }
            .to change { ActivityPub::Activity::Accept.count }.by(1)
          accept = ActivityPub::Activity::Accept.all.last
          expect(accept.actor).to eq(account.actor)
          expect(accept.object?).to eq(quote_request_activity)
          expect(accept.result?).to be_a(ActivityPub::Object::QuoteAuthorization)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, quote_request_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(quote_request_activity)
        end

        it "schedules deliver task" do
          InboxActivityProcessor.process(account, quote_request_activity, deliver_task_class: MockDeliverTask)
          expect(MockDeliverTask.schedule_called_count).to eq(1)
          expect(MockDeliverTask.last_sender).to eq(account.actor)
          expect(MockDeliverTask.last_activity).to be_a(ActivityPub::Activity::Accept)
        end

        it "creates a quote notification" do
          expect { InboxActivityProcessor.process(account, quote_request_activity) }
            .to change { Relationship::Content::Notification::Quote.count }.by(1)
        end

        it "sets the notification owner to the account actor" do
          InboxActivityProcessor.process(account, quote_request_activity)
          notification = Relationship::Content::Notification::Quote.all.last
          expect(notification.owner).to eq(account.actor)
        end

        it "sets the notification activity to the quote request" do
          InboxActivityProcessor.process(account, quote_request_activity)
          notification = Relationship::Content::Notification::Quote.all.last
          expect(notification.activity).to eq(quote_request_activity)
        end

        context "given an existing quote authorization" do
          let_create!(:quote_authorization, attributed_to: account.actor)
          let_create!(:quote_decision, quote_authorization: quote_authorization, interaction_target_iri: note.iri, interacting_object_iri: "https://remote/objects/123", decision: "accept")

          it "reuses the existing quote authorization" do
            expect { InboxActivityProcessor.process(account, quote_request_activity) }
              .not_to change { ActivityPub::Object::QuoteAuthorization.count }
          end

          it "creates a new accept activity" do
            expect { InboxActivityProcessor.process(account, quote_request_activity) }
              .to change { ActivityPub::Activity::Accept.count }.by(1)
            accept = ActivityPub::Activity::Accept.all.last
            expect(accept.result).to eq(quote_authorization)
          end
        end

        context "and the request has already been accepted" do
          before_each { InboxActivityProcessor.process(account, quote_request_activity) }

          it "does not create a second Accept" do
            expect { InboxActivityProcessor.process(account, quote_request_activity) }
              .not_to change { ActivityPub::Activity::Accept.count }
          end

          it "does not create a second notification" do
            expect { InboxActivityProcessor.process(account, quote_request_activity) }
              .not_to change { Relationship::Content::Notification::Quote.count }
          end

          it "does not schedule a second deliver task" do
            InboxActivityProcessor.process(account, quote_request_activity, deliver_task_class: MockDeliverTask)
            expect(MockDeliverTask.schedule_called_count).to eq(0)
          end
        end
      end

      # a request is answered once; toggling the setting between an
      # original delivery and a redelivery must not produce a second,
      # contradictory answer
      context "when manually_approve_quotes is toggled between deliveries" do
        context "rejected, then approval turned off" do
          before_each do
            account.assign(manually_approve_quotes: true).save
            InboxActivityProcessor.process(account, quote_request_activity)
            account.assign(manually_approve_quotes: false).save
          end

          it "does not accept it" do
            expect { InboxActivityProcessor.process(account, quote_request_activity) }
              .not_to change { ActivityPub::Activity::Accept.count }
          end
        end

        context "accepted, then approval turned on" do
          before_each do
            account.assign(manually_approve_quotes: false).save
            InboxActivityProcessor.process(account, quote_request_activity)
            account.assign(manually_approve_quotes: true).save
          end

          it "does not reject it" do
            expect { InboxActivityProcessor.process(account, quote_request_activity) }
              .not_to change { ActivityPub::Activity::Reject.count }
          end
        end
      end
    end

    context "recipient partitioning" do
      let_create(:actor, named: :follower)
      let(followers) { ["#{account.actor.iri}/followers"] }
      let_create!(:object, named: :origin, attributed_to: account.actor, to: followers)
      let_create!(:object, named: :reply, attributed_to: other, in_reply_to: origin, to: followers)
      let_create(:create, named: :activity, actor: other, object: reply, to: followers)

      before_each { do_follow(follower, account.actor) }

      it "passes remote recipients to the receive task" do
        InboxActivityProcessor.process(account, activity, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.last_recipients).to eq([follower.iri])
      end

      it "schedules the receive task" do
        InboxActivityProcessor.process(account, activity, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
      end
    end

    context "scheduling the receive task" do
      let_create(:create, named: :activity, actor: other, object: object)

      it "does not schedule the task" do
        InboxActivityProcessor.process(account, activity, recipients: [] of Account, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(0)
      end

      context "given a resolved recipient" do
        let!(recipient) { register }

        it "makes the recipient the receiver" do
          InboxActivityProcessor.process(account, activity, recipients: [recipient], receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.last_receiver).to eq(recipient.actor)
        end

        it "forwards to nobody" do
          InboxActivityProcessor.process(account, activity, recipients: [recipient], receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.last_recipients).to be_empty
        end

        it "schedules one task" do
          InboxActivityProcessor.process(account, activity, recipients: [recipient], receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
        end

        context "and a second recipient" do
          let!(second_recipient) { register }

          it "still schedules one task" do
            InboxActivityProcessor.process(account, activity, recipients: [recipient, second_recipient], receive_task_class: MockReceiveTask)
            expect(MockReceiveTask.schedule_called_count).to eq(1)
          end
        end
      end

      context "given an addressed followers collection" do
        let!(collection_owner) { register }
        let(followers) { ["#{collection_owner.actor.iri}/followers"] }
        let_create(:actor, named: :follower)
        let_create!(:object, named: :origin, attributed_to: collection_owner.actor, to: followers)
        let_create!(:object, named: :reply, attributed_to: other, in_reply_to: origin, to: followers)
        let_create(:create, named: :activity, actor: other, object: reply, to: followers)

        before_each { do_follow(follower, collection_owner.actor) }

        it "makes the collection's owner the receiver" do
          InboxActivityProcessor.process(account, activity, recipients: [] of Account, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.last_receiver).to eq(collection_owner.actor)
        end

        it "forwards to the owner's remote followers" do
          InboxActivityProcessor.process(account, activity, recipients: [] of Account, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.last_recipients).to eq([follower.iri])
        end

        it "schedules one task" do
          InboxActivityProcessor.process(account, activity, recipients: [] of Account, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
        end

        context "and one of the owner's followers is local" do
          let!(local_follower) { register }

          before_each { do_follow(local_follower.actor, collection_owner.actor) }

          it "still makes the collection's owner the receiver" do
            InboxActivityProcessor.process(account, activity, recipients: [local_follower], receive_task_class: MockReceiveTask)
            expect(MockReceiveTask.last_receiver).to eq(collection_owner.actor)
          end
        end
      end
    end

    context "with an Announce of the owner's object" do
      let_create!(:object, named: announced, attributed_to: account.actor)
      let_create!(:announce, named: announce_activity, actor: other, object: announced, to: [account.actor.iri])

      it "materializes the announce notification" do
        expect { InboxActivityProcessor.process(account, announce_activity, receive_task_class: MockReceiveTask) }
          .to change { Relationship::Content::Notification::Announce.count(from_iri: account.actor.iri, to_iri: announce_activity.iri) }.from(0).to(1)
      end

      context "and the announce is undone" do
        let_create!(:undo, named: undo_activity, actor: other, object: announce_activity, to: [account.actor.iri])
        let_create!(:notification_announce, owner: account.actor, activity: announce_activity)

        pre_condition { expect(Relationship::Content::Notification::Announce.count(to_iri: announce_activity.iri)).to eq(1) }

        it "evicts the announce notification" do
          expect { InboxActivityProcessor.process(account, undo_activity, receive_task_class: MockReceiveTask) }
            .to change { Relationship::Content::Notification::Announce.count(to_iri: announce_activity.iri) }.from(1).to(0)
        end
      end
    end

    context "with a Like of the owner's object" do
      let_create!(:object, named: liked, attributed_to: account.actor)
      let_create!(:like, named: like_activity, actor: other, object: liked, to: [account.actor.iri])

      it "materializes the like notification" do
        expect { InboxActivityProcessor.process(account, like_activity, receive_task_class: MockReceiveTask) }
          .to change { Relationship::Content::Notification::Like.count(from_iri: account.actor.iri, to_iri: like_activity.iri) }.from(0).to(1)
      end

      context "and the like is undone" do
        let_create!(:undo, named: undo_activity, actor: other, object: like_activity, to: [account.actor.iri])
        let_create!(:notification_like, owner: account.actor, activity: like_activity)

        pre_condition { expect(Relationship::Content::Notification::Like.count(to_iri: like_activity.iri)).to eq(1) }

        it "evicts the like notification" do
          expect { InboxActivityProcessor.process(account, undo_activity, receive_task_class: MockReceiveTask) }
            .to change { Relationship::Content::Notification::Like.count(to_iri: like_activity.iri) }.from(1).to(0)
        end
      end
    end

    context "with a Dislike of the owner's object" do
      let_create!(:object, named: disliked, attributed_to: account.actor)
      let_create!(:dislike, named: dislike_activity, actor: other, object: disliked, to: [account.actor.iri])

      it "materializes the dislike notification" do
        expect { InboxActivityProcessor.process(account, dislike_activity, receive_task_class: MockReceiveTask) }
          .to change { Relationship::Content::Notification::Dislike.count(from_iri: account.actor.iri, to_iri: dislike_activity.iri) }.from(0).to(1)
      end

      context "and the dislike is undone" do
        let_create!(:undo, named: undo_activity, actor: other, object: dislike_activity, to: [account.actor.iri])
        let_create!(:notification_dislike, owner: account.actor, activity: dislike_activity)

        pre_condition { expect(Relationship::Content::Notification::Dislike.count(to_iri: dislike_activity.iri)).to eq(1) }

        it "evicts the dislike notification" do
          expect { InboxActivityProcessor.process(account, undo_activity, receive_task_class: MockReceiveTask) }
            .to change { Relationship::Content::Notification::Dislike.count(to_iri: dislike_activity.iri) }.from(1).to(0)
        end
      end
    end

    context "with a Follow of the account's actor" do
      let_create!(:follow, named: follow_activity, actor: other, object: account.actor, to: [account.actor.iri])

      it "materializes the follow notification" do
        expect { InboxActivityProcessor.process(account, follow_activity, receive_task_class: MockReceiveTask) }
          .to change { Relationship::Content::Notification::Follow.count(from_iri: account.actor.iri, to_iri: follow_activity.iri) }.from(0).to(1)
      end

      context "and the follow is undone" do
        let_create!(:undo, named: undo_activity, actor: other, object: follow_activity, to: [account.actor.iri])
        let_create!(:notification_follow, owner: account.actor, activity: follow_activity)

        pre_condition { expect(Relationship::Content::Notification::Follow.count(to_iri: follow_activity.iri)).to eq(1) }

        it "evicts the follow notification" do
          expect { InboxActivityProcessor.process(account, undo_activity, receive_task_class: MockReceiveTask) }
            .to change { Relationship::Content::Notification::Follow.count(to_iri: follow_activity.iri) }.from(1).to(0)
        end
      end
    end

    context "with a reply to one of the account's posts" do
      let_create!(:object, named: post, attributed_to: account.actor)
      let_create!(:object, named: reply, attributed_to: other, in_reply_to: post)
      let_create!(:create, named: reply_create, actor: other, object: reply, to: [account.actor.iri])

      it "materializes the reply notification" do
        expect { InboxActivityProcessor.process(account, reply_create, receive_task_class: MockReceiveTask) }
          .to change { Relationship::Content::Notification::Reply.count(to_iri: reply.iri) }.from(0).to(1)
      end
    end

    context "with an object mentioning the account's actor" do
      let_create!(:object, named: mentioning, attributed_to: other)
      let_create!(:mention, named: nil, name: "actor", href: account.actor.iri, subject: mentioning)
      let_create!(:create, named: mention_create, actor: other, object: mentioning, to: [account.actor.iri])

      it "materializes the mention notification" do
        expect { InboxActivityProcessor.process(account, mention_create, receive_task_class: MockReceiveTask) }
          .to change { Relationship::Content::Notification::Mention.count(to_iri: mentioning.iri) }.from(0).to(1)
      end
    end

    # reply wins: an object that both replies to the actor's post and
    # mentions the actor yields exactly one notification -- the reply.
    context "with an object both replying to and mentioning the account's actor" do
      let_create!(:object, named: post, attributed_to: account.actor)
      let_create!(:object, named: dual, attributed_to: other, in_reply_to: post)
      let_create!(:mention, named: nil, name: "actor", href: account.actor.iri, subject: dual)
      let_create!(:create, named: dual_create, actor: other, object: dual, to: [account.actor.iri])

      it "materializes the reply notification" do
        expect { InboxActivityProcessor.process(account, dual_create, receive_task_class: MockReceiveTask) }
          .to change { Relationship::Content::Notification::Reply.count(to_iri: dual.iri) }.from(0).to(1)
      end

      it "does not materialize a mention notification" do
        InboxActivityProcessor.process(account, dual_create, receive_task_class: MockReceiveTask)
        expect(Relationship::Content::Notification::Mention.count(to_iri: dual.iri)).to eq(0)
      end
    end

    context "with a Create of an object in the owner's timeline" do
      let_create!(:object, named: posted, attributed_to: other)
      let_create!(:create, named: create_activity, actor: other, object: posted, to: [account.actor.iri])

      it "materializes the timeline entry" do
        expect { InboxActivityProcessor.process(account, create_activity, receive_task_class: MockReceiveTask) }
          .to change { Relationship::Content::Timeline::Create.count(from_iri: account.actor.iri, to_iri: posted.iri) }.from(0).to(1)
      end

      context "and the object is deleted" do
        let_create!(:delete, named: delete_activity, actor: other, object: posted, to: [account.actor.iri])

        before_each { InboxActivityProcessor.process(account, create_activity, receive_task_class: MockReceiveTask) }

        pre_condition { expect(Relationship::Content::Timeline::Create.count(to_iri: posted.iri)).to eq(1) }

        it "evicts the timeline entry" do
          expect { InboxActivityProcessor.process(account, delete_activity, receive_task_class: MockReceiveTask) }
            .to change { Relationship::Content::Timeline::Create.count(to_iri: posted.iri) }.from(1).to(0)
        end
      end
    end

    context "with an Announce of an object in the owner's timeline" do
      let_create!(:object, named: shared, attributed_to: other)
      let_create!(:announce, named: announce_activity, actor: other, object: shared, to: [account.actor.iri])

      it "materializes the timeline entry" do
        expect { InboxActivityProcessor.process(account, announce_activity, receive_task_class: MockReceiveTask) }
          .to change { Relationship::Content::Timeline::Announce.count(from_iri: account.actor.iri, to_iri: shared.iri) }.from(0).to(1)
      end

      context "and the announce is undone" do
        let_create!(:undo, named: undo_activity, actor: other, object: announce_activity, to: [account.actor.iri])

        before_each { InboxActivityProcessor.process(account, announce_activity, receive_task_class: MockReceiveTask) }

        pre_condition { expect(Relationship::Content::Timeline::Announce.count(to_iri: shared.iri)).to eq(1) }

        it "evicts the timeline entry" do
          expect { InboxActivityProcessor.process(account, undo_activity, receive_task_class: MockReceiveTask) }
            .to change { Relationship::Content::Timeline::Announce.count(to_iri: shared.iri) }.from(1).to(0)
        end
      end
    end
  end

  describe ".maintain" do
    context "with a Delete of an Object" do
      let_create!(:object, named: :doomed, attributed_to: other)
      let_create(:delete, named: :delete_activity, actor: other, object: doomed)

      it "marks the object as deleted" do
        expect { InboxActivityProcessor.maintain(delete_activity) }
          .to change { ActivityPub::Object.find(doomed.iri, include_deleted: true).deleted_at }.from(nil)
      end
    end

    context "with an Undo of a Follow" do
      let_create(:follow, named: :follow_activity, actor: other, object: account.actor)
      let_create!(:follow_relationship, actor: other, object: account.actor)
      let_create(:undo, named: :undo_activity, actor: other, object: follow_activity)

      it "marks the follow activity as undone" do
        expect { InboxActivityProcessor.maintain(undo_activity) }
          .to change { follow_activity.reload!.undone_at }.from(nil)
      end

      it "destroys the follow relationship" do
        expect { InboxActivityProcessor.maintain(undo_activity) }
          .to change { Relationship::Social::Follow.count }.by(-1)
      end

      it "does not create an inbox row" do
        expect { InboxActivityProcessor.maintain(undo_activity) }
          .not_to change { Relationship::Content::Inbox.count }
      end
    end

    context "with an Accept of a Follow" do
      let_create(:follow, named: :follow_activity, actor: account.actor, object: other)
      let_create(:follow_relationship, actor: account.actor, object: other, confirmed: false)
      let_create(:accept, named: :accept_activity, actor: other, object: follow_activity)

      it "confirms the follow relationship" do
        expect { InboxActivityProcessor.maintain(accept_activity) }
          .to change { follow_relationship.reload!.confirmed }.from(false).to(true)
      end
    end

    context "with a Reject of a Follow" do
      let_create(:follow, named: :follow_activity, actor: account.actor, object: other)
      let_create(:follow_relationship, actor: account.actor, object: other, confirmed: false)
      let_create(:reject, named: :reject_activity, actor: other, object: follow_activity)

      it "confirms the follow relationship" do
        expect { InboxActivityProcessor.maintain(reject_activity) }
          .to change { follow_relationship.reload!.confirmed }.from(false).to(true)
      end
    end
  end

  describe ".deliver" do
    let_create(:create, named: :create_activity, actor: other, object: object, to: [account.actor.iri])

    it "creates the inbox row" do
      expect { InboxActivityProcessor.deliver(account, create_activity) }
        .to change { Relationship::Content::Inbox.count(from_iri: account.actor.iri) }.by(1)
    end

    context "with an Undo of a Follow" do
      let_create(:follow, named: :follow_activity, actor: other, object: account.actor)
      let_create!(:follow_relationship, actor: other, object: account.actor)
      let_create(:undo, named: :undo_activity, actor: other, object: follow_activity, to: [account.actor.iri])

      it "does not undo the target" do
        expect { InboxActivityProcessor.deliver(account, undo_activity) }
          .not_to change { follow_activity.reload!.undone_at }
      end

      it "does not destroy the follow relationship" do
        expect { InboxActivityProcessor.deliver(account, undo_activity) }
          .not_to change { Relationship::Social::Follow.count }
      end

      it "creates the inbox row" do
        expect { InboxActivityProcessor.deliver(account, undo_activity) }
          .to change { Relationship::Content::Inbox.count(from_iri: account.actor.iri) }.by(1)
      end
    end
  end
end
