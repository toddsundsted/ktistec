require "../../../src/models/task/collect_garbage"
require "../../../src/models/relationship/content/follow/hashtag"
require "../../../src/models/relationship/content/follow/mention"
require "../../../src/models/relationship/content/follow/thread"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::CollectGarbage do
  setup_spec

  describe ".ensure_scheduled" do
    it "schedules a new task" do
      expect { described_class.ensure_scheduled }.to change { described_class.count }.by(1)
    end

    context "given an existing task" do
      before_each { described_class.new.schedule }

      it "does not schedule a new task" do
        expect { described_class.ensure_scheduled }.not_to change { described_class.count }
      end
    end
  end

  let(actor) { register.actor }
  let_create!(actor, named: other)
  let_create!(object, attributed_to: other)

  TOO_OLD = (Task::CollectGarbage::DEFAULT_MAX_AGE_DAYS + 1).days.ago

  NOT_TOO_OLD = (Task::CollectGarbage::DEFAULT_MAX_AGE_DAYS - 1).days.ago

  describe ".objects_attributed_to_user" do
    let(results) { Ktistec.database.query_all(described_class.objects_attributed_to_user, as: String) }

    it "is empty" do
      expect(results).to be_empty
    end

    context "given object attributed to user" do
      before_each { object.assign(attributed_to: actor).save }

      it "returns the object" do
        expect(results).to have(object.iri)
      end
    end

    context "given object attributed to non-existent user" do
      before_each { object.assign(attributed_to_iri: "https://example.com/users/nonexistent").save }

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end
    end

    context "given object attributed to no one" do
      before_each { object.assign(attributed_to_iri: nil).save }

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end
    end
  end

  describe ".objects_attributed_to_followed_actors" do
    let(results) do
      query = <<-SQL
      WITH
      followed_or_following_actors AS (
        #{described_class.followed_or_following_actors}
      )
      #{described_class.objects_attributed_to_followed_actors}
      SQL
      Ktistec.database.query_all(query, as: String)
    end

    it "is empty" do
      expect(results).to be_empty
    end

    context "given object attributed to remote actor" do
      before_each { object.assign(attributed_to: other).save }

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end

      context "and a follow" do
        before_each { do_follow(actor, other) }

        it "returns the object" do
          expect(results).to have(object.iri)
        end
      end
    end
  end

  describe ".objects_associated_with_user_activities" do
    let(results) { Ktistec.database.query_all(described_class.objects_associated_with_user_activities, as: String) }

    it "is empty" do
      expect(results).to be_empty
    end

    # via `object` property

    context "given activity by local actor" do
      let_create!(activity, actor: actor, object: object)

      it "returns the object" do
        expect(results).to have(object.iri)
      end
    end

    context "given activity by remote actor" do
      let_create!(activity, actor: other, object: object)

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end
    end

    # via `target` property

    context "given activity by local actor" do
      let_create!(activity, actor: actor, target: object)

      it "returns the object" do
        expect(results).to have(object.iri)
      end
    end

    context "given activity by remote actor" do
      let_create!(activity, actor: other, target: object)

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end
    end
  end

  describe ".objects_associated_with_followed_actor_activities" do
    let(results) do
      query = <<-SQL
      WITH
      followed_or_following_actors AS (
        #{described_class.followed_or_following_actors}
      )
      #{described_class.objects_associated_with_followed_actor_activities}
      SQL
      Ktistec.database.query_all(query, as: String)
    end

    it "is empty" do
      expect(results).to be_empty
    end

    # via `object` property

    context "given activity by remote actor" do
      let_create!(activity, actor: other, object: object)

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end

      context "and a follow" do
        before_each { do_follow(actor, other) }

        it "returns the object" do
          expect(results).to have(object.iri)
        end
      end
    end

    # via `target` property

    context "given activity by remote actor" do
      let_create!(activity, actor: other, target: object)

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end

      context "and a follow" do
        before_each { do_follow(actor, other) }

        it "returns the object" do
          expect(results).to have(object.iri)
        end
      end
    end
  end

  describe ".objects_associated_with_followed_content" do
    let(results) do
      query = <<-SQL
      WITH
      followed_hashtags AS (
        #{described_class.followed_hashtags}
      ),
      followed_mentions AS (
        #{described_class.followed_mentions}
      ),
      followed_threads AS (
        #{described_class.followed_threads}
      )
      #{described_class.objects_associated_with_followed_content}
      SQL
      Ktistec.database.query_all(query, as: String)
    end

    it "is empty" do
      expect(results).to be_empty
    end

    context "given object with hashtag" do
      let_create!(hashtag, name: "test", subject: object)

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end

      context "and user follows hashtag" do
        let_create!(follow_hashtag_relationship, actor: actor, name: hashtag.name)

        it "returns the object" do
          expect(results).to have(object.iri)
        end
      end
    end

    context "given object with mention" do
      let_create!(mention, name: "test", href: "https://example.com/@test", subject: object)

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end

      context "and user follows mention" do
        let_create!(follow_mention_relationship, actor: actor, name: mention.href)

        it "returns the object" do
          expect(results).to have(object.iri)
        end
      end
    end

    context "given object in thread" do
      before_each { object.assign(thread: "https://example.com/thread/123").save }

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end

      context "and user follows thread" do
        let_create!(follow_thread_relationship, actor: actor, thread: object.thread)

        it "returns the object" do
          expect(results).to have(object.iri)
        end
      end
    end
  end

  describe ".objects_in_user_relationships" do
    let(results) { Ktistec.database.query_all(described_class.objects_in_user_relationships, as: String) }

    it "is empty" do
      expect(results).to be_empty
    end

    # objects directly referenced by relationships

    context "given object in timeline relationship" do
      let_create!(timeline, owner: actor, object: object)

      it "returns the object" do
        expect(results).to have(object.iri)
      end
    end

    context "given object in notification relationship" do
      let_create!(notification_mention, owner: actor, object: object)

      it "returns the object" do
        expect(results).to have(object.iri)
      end
    end

    context "given object in notification relationship" do
      let_create!(notification_reply, owner: actor, object: object)

      it "returns the object" do
        expect(results).to have(object.iri)
      end
    end

    # objects referenced by activities in relationships

    context "given activity in inbox relationship (object)" do
      let_create!(create, actor: other, object: object)
      let_create!(inbox_relationship, owner: actor, activity: create)

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end
    end

    context "given activity in outbox relationship (object)" do
      let_create!(create, actor: actor, object: object)
      let_create!(outbox_relationship, owner: actor, activity: create)

      it "returns the object" do
        expect(results).to have(object.iri)
      end
    end

    context "given activity in inbox relationship (target)" do
      let_create!(announce, actor: other, target: object)
      let_create!(inbox_relationship, owner: actor, activity: announce)

      it "does not return the object" do
        expect(results).not_to have(object.iri)
      end
    end

    context "given activity in outbox relationship (target)" do
      let_create!(announce, actor: actor, target: object)
      let_create!(outbox_relationship, owner: actor, activity: announce)

      it "returns the object" do
        expect(results).to have(object.iri)
      end
    end

    context "given activity in notification relationship (object)" do
      let_create!(like, actor: other, object: object)
      let_create!(notification_like, owner: actor, activity: like)

      it "returns the object" do
        expect(results).to have(object.iri)
      end
    end

    context "given activity in notification relationship (target)" do
      let_create!(announce, actor: other, target: object)
      let_create!(notification_announce, owner: actor, activity: announce)

      it "returns the object" do
        expect(results).to have(object.iri)
      end
    end

    # edge cases

    context "given object with multiple relationship types" do
      let_create!(timeline, owner: actor, object: object)
      let_create!(create, actor: actor, object: object)
      let_create!(outbox_relationship, owner: actor, activity: create)
      let_create!(inbox_relationship, owner: actor, activity: create)

      it "returns the object once (deduplicated)" do
        expect(results.count(object.iri)).to eq(1)
      end
    end

    context "given activity with object and target in relationships" do
      let_create(object, named: target)
      let_create!(announce, actor: other, object: object, target: target)
      let_create!(notification_announce, owner: actor, activity: announce)

      it "returns both the object and target" do
        expect(results).to have(object.iri, target.iri)
      end
    end
  end

  describe ".objects_too_recent_to_delete" do
    let(results) { Ktistec.database.query_all(described_class.objects_too_recent_to_delete, as: String) }

    let_create!(object, created_at: 5.days.ago)
    let_create!(object, named: not_too_old, created_at: NOT_TOO_OLD)
    let_create!(object, named: too_old, created_at: TOO_OLD)

    it "returns recent objects" do
      expect(results).to have(object.iri, not_too_old.iri)
      expect(results).not_to have(too_old.iri)
    end
  end

  describe ".objects_in_threads" do
    let(results) do
      query = <<-SQL
      WITH
      followed_or_following_actors AS (
        #{described_class.followed_or_following_actors}
      ),
      followed_hashtags AS (
        #{described_class.followed_hashtags}
      ),
      followed_mentions AS (
        #{described_class.followed_mentions}
      ),
      followed_threads AS (
        #{described_class.followed_threads}
      )
      #{described_class.objects_in_threads}
      SQL
      Ktistec.database.query_all(query, as: String)
    end

    it "is empty" do
      expect(results).to be_empty
    end

    context "given a thread" do
      let_create!(object, named: root)
      let_create!(object, named: reply1, in_reply_to: root)
      let_create!(object, named: reply2, in_reply_to: reply1)
      let_create!(object, named: reply3, in_reply_to: root)

      it "does not return any objects" do
        expect(results).not_to have(root.iri, reply1.iri, reply2.iri, reply3.iri)
      end

      context "given object attributed to user" do
        before_each { reply1.assign(attributed_to: actor).save }

        it "returns all objects" do
          expect(results).to have(root.iri, reply1.iri, reply2.iri, reply3.iri)
        end

        # A legacy thread is set of objects related by their
        # `in_reply_to_iri` values, but whose `thread` values are
        # `nil` (legacy threads are lazily migrated when followed or
        # fetched).

        context "but thread is legacy" do
          before_each do
            Ktistec.database.exec(
              "UPDATE objects SET thread = NULL WHERE iri IN (?, ?, ?, ?)",
              root.iri,
              reply1.iri,
              reply2.iri,
              reply3.iri,
            )
          end

          it "returns all objects" do
            expect(results).to have(root.iri, reply1.iri, reply2.iri, reply3.iri)
          end
        end
      end

      context "given object associated with user activity (object)" do
        let_create!(activity, actor: actor, object: reply2)

        it "returns all objects" do
          expect(results).to have(root.iri, reply1.iri, reply2.iri)
        end
      end

      context "given object associated with user activity (target)" do
        let_create!(activity, actor: actor, object: reply2)

        it "returns all objects" do
          expect(results).to have(root.iri, reply1.iri, reply2.iri)
        end
      end

      context "given object associated with remote actor activity (object)" do
        let_create!(activity, actor: other, object: reply1)

        it "does not return any objects" do
          expect(results).not_to have(root.iri, reply1.iri, reply2.iri)
        end

        context "and a follow" do
          before_each { do_follow(actor, other) }

          it "returns all objects" do
            expect(results).to have(root.iri, reply1.iri, reply2.iri)
          end
        end
      end

      context "given object associated with remote actor activity (target)" do
        let_create!(activity, actor: other, target: reply1)

        it "does not return any objects" do
          expect(results).not_to have(root.iri, reply1.iri, reply2.iri)
        end

        context "and a follow" do
          before_each { do_follow(actor, other) }

          it "returns all objects" do
            expect(results).to have(root.iri, reply1.iri, reply2.iri)
          end
        end
      end

      context "given object attributed remote actor" do
        before_each { reply1.assign(attributed_to: other).save }

        it "does not return any objects" do
          expect(results).not_to have(root.iri, reply1.iri, reply2.iri)
        end

        context "and a follow" do
          before_each { do_follow(actor, other) }

          it "returns all objects" do
            expect(results).to have(root.iri, reply1.iri, reply2.iri)
          end
        end
      end

      context "given object has hashtag" do
        let_create!(hashtag, name: "test", subject: reply2)

        it "does not return any objects" do
          expect(results).not_to have(root.iri, reply1.iri, reply2.iri)
        end

        context "and a hashtag follow" do
          let_create!(follow_hashtag_relationship, actor: actor, name: hashtag.name)

          it "returns all objects" do
            expect(results).to have(root.iri, reply1.iri, reply2.iri)
          end
        end
      end

      context "given object has mention" do
        let_create!(mention, name: "test", href: "https://example.com/@test", subject: reply1)

        it "does not return any objects" do
          expect(results).not_to have(root.iri, reply1.iri, reply2.iri)
        end

        context "and a mention follow" do
          let_create!(follow_mention_relationship, actor: actor, name: mention.href)

          it "returns all objects" do
            expect(results).to have(root.iri, reply1.iri, reply2.iri)
          end
        end
      end

      context "given thread is followed" do
        let_create!(follow_thread_relationship, actor: actor, thread: root.thread)

        it "returns all objects" do
          expect(results).to have(root.iri, reply1.iri, reply2.iri)
        end
      end

      context "given object in timeline relationship" do
        let_create!(timeline, owner: actor, object: reply1)

        it "returns all objects" do
          expect(results).to have(root.iri, reply1.iri, reply2.iri)
        end
      end

      context "given activity in notification relationship (object)" do
        let_create!(like, actor: other, object: reply1)
        let_create!(notification_like, owner: actor, activity: like)

        it "returns all objects" do
          expect(results).to have(root.iri, reply1.iri, reply2.iri)
        end
      end

      context "given activity in notification relationship (target)" do
        let_create!(announce, actor: other, target: reply2)
        let_create!(notification_announce, owner: actor, activity: announce)

        it "returns all objects" do
          expect(results).to have(root.iri, reply1.iri, reply2.iri)
        end
      end

      context "when object is recent" do
        before_each { reply1.assign(created_at: 5.days.ago).save }

        it "returns all objects" do
          expect(results).to have(root.iri, reply1.iri, reply2.iri)
        end
      end
    end
  end

  describe "#perform" do
    before_each { object.assign(created_at: NOT_TOO_OLD).save }

    it "sets the next attempt at" do
      subject.perform
      expect(subject.next_attempt_at).not_to be_nil
    end

    it "does not destroy the object" do
      subject.perform
      expect(object.reload!).to eq(object)
    end

    context "when the object is too old" do
      before_each { object.assign(created_at: TOO_OLD).save }

      it "destroys the object" do
        subject.perform
        expect { object.reload! }.to raise_error(Ktistec::Model::NotFound)
      end

      context "given object attributed to user" do
        before_each { object.assign(attributed_to: actor).save }

        it "preserves object" do
          subject.perform
          expect(object.reload!).to eq(object)
        end
      end

      context "given object associated with user activity (object)" do
        let_create!(activity, actor: actor, object: object)

        it "preserves the object" do
          subject.perform
          expect(object.reload!).to eq(object)
        end
      end

      context "given object associated with user activity (target)" do
        let_create!(activity, actor: actor, target: object)

        it "preserves the object" do
          subject.perform
          expect(object.reload!).to eq(object)
        end
      end

      context "given object associated with remote actor activity (object)" do
        let_create!(activity, actor: other, object: object)

        it "destroys the object" do
          subject.perform
          expect { object.reload! }.to raise_error(Ktistec::Model::NotFound)
        end

        context "and a follow" do
          before_each { do_follow(actor, other) }

          it "preserves the object" do
            subject.perform
            expect(object.reload!).to eq(object)
          end
        end
      end

      context "given object associated with remote actor activity (target)" do
        let_create!(activity, actor: other, object: object)

        it "destroys the object" do
          subject.perform
          expect { object.reload! }.to raise_error(Ktistec::Model::NotFound)
        end

        context "and a follow" do
          before_each { do_follow(actor, other) }

          it "preserves the object" do
            subject.perform
            expect(object.reload!).to eq(object)
          end
        end
      end

      context "given object attributed remote actor" do
        before_each { object.assign(attributed_to: other).save }

        it "destroys the object" do
          subject.perform
          expect { object.reload! }.to raise_error(Ktistec::Model::NotFound)
        end

        context "and a follow" do
          before_each { do_follow(actor, other) }

          it "preserves the object" do
            subject.perform
            expect(object.reload!).to eq(object)
          end
        end
      end

      context "given object has hashtag" do
        let_create!(hashtag, name: "test", subject: object)

        it "destroys the object" do
          subject.perform
          expect { object.reload! }.to raise_error(Ktistec::Model::NotFound)
        end

        context "and a hashtag follow" do
          let_create!(follow_hashtag_relationship, actor: actor, name: hashtag.name)

          it "preserves the object" do
            subject.perform
            expect(object.reload!).to eq(object)
          end
        end
      end

      context "given object has mention" do
        let_create!(mention, name: "test", href: "https://example.com/@test", subject: object)

        it "destroys the object" do
          subject.perform
          expect { object.reload! }.to raise_error(Ktistec::Model::NotFound)
        end

        context "and a mention follow" do
          let_create!(follow_mention_relationship, actor: actor, name: mention.href)

          it "preserves the object" do
            subject.perform
            expect(object.reload!).to eq(object)
          end
        end
      end

      context "given a thread" do
        before_each { object.assign(thread: "https://example.com/thread/123").save }

        it "destroys the object" do
          subject.perform
          expect { object.reload! }.to raise_error(Ktistec::Model::NotFound)
        end

        context "and a thread follow" do
          let_create!(follow_thread_relationship, actor: actor, thread: object.thread)

          it "preserves the object" do
            subject.perform
            expect(object.reload!).to eq(object)
          end
        end
      end

      context "given a thread" do
        let_create!(object, named: reply1, in_reply_to: object)
        let_create!(object, named: reply2, in_reply_to: object)

        it "destroys the thread" do
          subject.perform
          expect { object.reload! }.to raise_error(Ktistec::Model::NotFound)
          expect { reply1.reload! }.to raise_error(Ktistec::Model::NotFound)
          expect { reply2.reload! }.to raise_error(Ktistec::Model::NotFound)
        end

        context "and one object is recent" do
          before_each { reply2.assign(created_at: NOT_TOO_OLD).save }

          it "preserves entire thread" do
            subject.perform
            expect(object.reload!).to eq(object)
            expect(reply1.reload!).to eq(reply1)
            expect(reply2.reload!).to eq(reply2)
          end
        end
      end

      context "given object in timeline relationship" do
        let_create!(timeline, owner: actor, object: object)

        it "preserves the object" do
          subject.perform
          expect(object.reload!).to eq(object)
        end
      end

      context "given activity in notification relationship (object)" do
        let_create!(like, actor: other, object: object)
        let_create!(notification_like, owner: actor, activity: like)

        it "preserves the object" do
          subject.perform
          expect(object.reload!).to eq(object)
        end
      end

      context "given activity in notification relationship (target)" do
        let_create!(announce, actor: other, target: object)
        let_create!(notification_announce, owner: actor, activity: announce)

        it "preserves the object" do
          subject.perform
          expect(object.reload!).to eq(object)
        end
      end

      context "given more objects than the max delete count" do
        before_each do
          11.times { Factory.create(:object, created_at: TOO_OLD) } # ameba:disable Ktistec/NoImperativeFactories
        end

        it "deletes only up to the maximum count" do
          expect { subject.perform(max_delete_count: 10) }.to change { ActivityPub::Object.count }.by(-10)
        end
      end
    end
  end

  describe "#delete_object_and_associations" do
    it "deletes the object" do
      expect { subject.delete_object_and_associations(object.iri) }.to change { ActivityPub::Object.count }.by(-1)
      expect { object.reload! }.to raise_error(Ktistec::Model::NotFound)
    end

    context "given object has hashtag" do
      let_create!(hashtag, name: "test", subject: object)

      it "deletes associated hashtag" do
        expect { subject.delete_object_and_associations(object.iri) }.to change { Tag::Hashtag.count }.by(-1)
        expect { hashtag.reload! }.to raise_error(Ktistec::Model::NotFound)
      end
    end

    context "given object has mention" do
      let_create!(mention, name: "test", href: "https://example.com/@test", subject: object)

      it "deletes associated mention" do
        expect { subject.delete_object_and_associations(object.iri) }.to change { Tag::Mention.count }.by(-1)
        expect { mention.reload! }.to raise_error(Ktistec::Model::NotFound)
      end
    end

    context "given associated activities" do
      let_create!(create, actor: actor, object: object)
      let_create!(like, actor: actor, object: object)
      let_create!(announce, actor: actor, object: object)

      it "deletes associated activities" do
        expect { subject.delete_object_and_associations(object.iri) }.to change { ActivityPub::Activity.count }.by(-3)
        expect { create.reload! }.to raise_error(Ktistec::Model::NotFound)
        expect { like.reload! }.to raise_error(Ktistec::Model::NotFound)
        expect { announce.reload! }.to raise_error(Ktistec::Model::NotFound)
      end

      context "and undo activity" do
        let_create!(undo, actor: actor, activity: create)

        it "deletes undo activity" do
          expect { subject.delete_object_and_associations(object.iri) }.to change { ActivityPub::Activity.count }.by(-4)
          expect { undo.reload! }.to raise_error(Ktistec::Model::NotFound)
        end
      end
    end

    context "given relationships" do
      let_create!(timeline, owner: actor, object: object)
      let_create(:activity, named: inbox_activity, actor: actor, object: object)
      let_create!(inbox_relationship, owner: actor, activity: inbox_activity)
      let_create(:activity, named: outbox_activity, actor: actor, object: object)
      let_create!(outbox_relationship, owner: actor, activity: outbox_activity)

      it "deletes timeline relationship" do
        expect { subject.delete_object_and_associations(object.iri) }.to change { Relationship::Content::Timeline.count }.by(-1)
        expect { timeline.reload! }.to raise_error(Ktistec::Model::NotFound)
      end

      it "deletes relationships" do
        expect { subject.delete_object_and_associations(object.iri) }.to change { Relationship.count }.by(-3)
        expect { inbox_relationship.activity.reload! }.to raise_error(Ktistec::Model::NotFound)
        expect { outbox_relationship.activity.reload! }.to raise_error(Ktistec::Model::NotFound)
        expect { inbox_relationship.reload! }.to raise_error(Ktistec::Model::NotFound)
        expect { outbox_relationship.reload! }.to raise_error(Ktistec::Model::NotFound)
      end
    end

    # Because of the way the ActivityPub protocol distributes posts,
    # it is very common for a server to only have part of a thread.
    # Because of this, Ktistec tries to be robust in the presence of
    # incomplete threads, and it is not necessary to cascade delete
    # other objects in the thread. They will be garbage collected in
    # their own time.

    context "given a thread" do
      let_create!(object, named: reply1, in_reply_to: object)
      let_create!(object, named: reply2, in_reply_to: reply1)

      it "deletes the object but not the replies" do
        expect { subject.delete_object_and_associations(object.iri) }.to change { ActivityPub::Object.count }.by(-1)
        expect { reply1.reload! }.to eq(reply1)
        expect { reply2.reload! }.to eq(reply2)
      end
    end

    context "given translation" do
      let_create!(translation, origin: object, language: "es", content: "Hola")

      it "deletes translation" do
        expect { subject.delete_object_and_associations(object.iri) }.to change { Translation.count }.by(-1)
        expect { translation.reload! }.to raise_error(Ktistec::Model::NotFound)
      end
    end

    it "returns the number of objects deleted" do
      result = subject.delete_object_and_associations(object.iri)
      expect(result).to eq(1)
    end

    context "complex scenario" do
      let_create!(hashtag, name: "test", subject: object)
      let_create!(mention, name: "test", href: "https://example.com/@test", subject: object)
      let_create!(activity, actor: actor, object: object)
      let_create!(timeline, owner: actor, object: object)
      let_create!(translation, origin: object, language: "fr", content: "Bonjour")
      let_create!(object, named: reply, in_reply_to: object)

      it "deletes all related entities in a single operation" do
        initial_object_count = ActivityPub::Object.count
        initial_tag_count = Tag.count
        initial_activity_count = ActivityPub::Activity.count
        initial_relationship_count = Relationship.count
        initial_translation_count = Translation.count

        subject.delete_object_and_associations(object.iri)

        # will delete: object, tags, activity, relationship, translation.

        expect(ActivityPub::Object.count).to eq(initial_object_count - 1) # does not delete the reply
        expect(Tag.count).to eq(initial_tag_count - 2)
        expect(ActivityPub::Activity.count).to eq(initial_activity_count - 1)
        expect(Relationship.count).to eq(initial_relationship_count - 1)
        expect(Translation.count).to eq(initial_translation_count - 1)
      end
    end
  end
end
