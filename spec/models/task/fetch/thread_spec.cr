require "../../../../src/models/task/fetch/thread"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"
require "../../../spec_helper/network"

Spectator.describe Task::Fetch::Thread do
  setup_spec

  let_create(:actor, named: :source, with_keys: true)

  let(options) do
    {
      source_iri: source.iri,
      subject_iri: "https://#{random_string}"
    }
  end

  context "validation" do
    it "rejects missing source" do
      new_task = described_class.new(**options.merge({source_iri: "missing"}))
      expect(new_task.valid?).to be_false
      expect(new_task.errors.keys).to contain_exactly("source")
    end

    it "rejects blank thread" do
      new_task = described_class.new(**options.merge({subject_iri: ""}))
      expect(new_task.valid?).to be_false
      expect(new_task.errors.keys).to contain("thread")
    end

    it "successfully validates instance" do
      new_task = described_class.new(**options)
      expect(new_task.valid?).to be_true
    end
  end

  describe "#thread=" do
    subject { described_class.new(**options) }

    it "sets subject_iri" do
      expect{subject.assign(thread: "https://thread")}.to change{subject.subject_iri}
    end
  end

  describe "#thread" do
    subject { described_class.new(**options) }

    it "gets subject_iri" do
      expect(subject.thread).to eq(subject.subject_iri)
    end
  end

  describe ".find_or_new" do
    it "instantiates a new task" do
      expect(described_class.find_or_new(**options).new_record?).to be_true
    end

    context "given an existing task" do
      let!(existing) { described_class.new(**options).save }

      it "finds the existing task" do
        expect(described_class.find_or_new(**options)).to eq(existing)
      end

      context "for the root of the thread" do
        let_create!(:object, named: :origin)
        let_create!(:object, named: :reply, iri: options[:subject_iri], in_reply_to_iri: origin.iri)

        before_each do
          existing.assign(thread: origin.thread).save
        end

        it "finds the existing task" do
          expect(described_class.find_or_new(**options)).to eq(existing)
        end
      end
    end
  end

  describe "#complete!" do
    subject { described_class.new(**options).save }

    it "makes the task not runnable" do
      expect{subject.complete!}.to change{subject.reload!.runnable?}.to(false)
    end
  end

  describe "#perform" do
    let_create(:object)

    subject do
      described_class.new(
        source: source,
        thread: object.thread
      ).save
    end

    it "sets the next attempt at" do
      subject.perform
      expect(subject.next_attempt_at).not_to be_nil
    end

    def find(iri)
      case iri
      when /objects/
        ActivityPub::Object.find(iri)
      when /actors/
        ActivityPub::Actor.find(iri)
      else
        raise "unsupported"
      end
    end

    def find?(iri)
      case iri
      when /objects/
        ActivityPub::Object.find?(iri)
      when /actors/
        ActivityPub::Actor.find?(iri)
      else
        raise "unsupported"
      end
    end

    context "given a thread with no replies" do
      before_each do
        HTTP::Client.objects << object
      end

      let(node) { subject.state.nodes.first }

      pre_condition { expect(node.id).to eq(object.id) }

      it "changes time of last attempt" do
        expect{subject.perform}.to change{node.last_attempt_at}
      end

      it "does not change time of last success" do
        expect{subject.perform}.not_to change{node.last_success_at}
      end
    end

    context "given a thread with one reply" do
      let_build(:object, named: :reply, in_reply_to_iri: object.iri)
      let_build(:collection, named: :replies, items_iris: [reply.iri])

      before_each do
        HTTP::Client.objects << reply
        HTTP::Client.actors << reply.attributed_to
        HTTP::Client.objects << object.assign(replies: replies).save # embedded
      end

      it "does not fetch the replies collection" do
        subject.perform
        expect(HTTP::Client.requests).not_to have("GET #{replies.iri}")
      end

      let(node) { subject.state.nodes.first }

      pre_condition { expect(node.id).to eq(object.id) }

      it "changes time of last attempt" do
        expect{subject.perform}.to change{node.last_attempt_at}
      end

      it "changes time of last success" do
        expect{subject.perform}.to change{node.last_success_at}
      end
    end

    context "given a thread with one reply" do
      let_build(:object, named: :reply, in_reply_to_iri: object.iri)
      let_build(:collection, named: :replies, iri: "#{object.iri}/replies", items_iris: [reply.iri])

      before_each do
        HTTP::Client.objects << reply
        HTTP::Client.actors << reply.attributed_to
        HTTP::Client.objects << object.assign(replies_iri: replies.iri).save # linked
        HTTP::Client.collections << replies
      end

      it "fetches the replies collection" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{replies.iri}")
      end

      let(node) { subject.state.nodes.first }

      pre_condition { expect(node.id).to eq(object.id) }

      it "changes time of last attempt" do
        expect{subject.perform}.to change{node.last_attempt_at}
      end

      it "changes time of last success" do
        expect{subject.perform}.to change{node.last_success_at}
      end
    end

    def horizon(task)
      task.state.nodes.map(&.id)
    end

    context "given a thread with a local reply" do
      let_build(:object, named: :origin)
      let_create(:object, named: :reply1, in_reply_to_iri: origin.iri)
      let_create(:object, local: true, in_reply_to_iri: reply1.iri) # shadows earlier definition
      let_create(:object, named: :reply2, in_reply_to_iri: object.iri)
      let_build(:collection, named: :replies, iri: "#{reply2.iri}/replies", items_iris: [reply3.iri])
      let_build(:object, named: :reply3, in_reply_to_iri: reply2.iri)

      before_each do
        HTTP::Client.objects << origin
        HTTP::Client.objects << reply1
        HTTP::Client.objects << reply2.assign(replies_iri: replies.iri)
        HTTP::Client.objects << reply3
        HTTP::Client.actors << origin.attributed_to
        HTTP::Client.actors << reply1.attributed_to
        HTTP::Client.actors << reply2.attributed_to
        HTTP::Client.actors << reply3.attributed_to
        HTTP::Client.collections << replies
        object.assign(replies_iri: "#{object.iri}/replies").save
      end

      it "starts with cached objects in the horizon" do
        expect(horizon(subject)).to contain(reply1.id, object.id, reply2.id)
      end

      it "fetches all the uncached objects" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{origin.iri}", "GET #{reply3.iri}")
      end

      it "persists all the uncached objects" do
        expect{subject.perform}.to change{ {find?(origin.iri), find?(reply3.iri)}.any?(&.nil?) }.to(false)
      end

      it "does not fetch the local object replies collection" do
        subject.perform
        expect(HTTP::Client.requests).not_to have("GET #{object.replies_iri}")
      end

      it "fetches the remote object replies collection" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{reply2.replies_iri}")
      end

      let(node) { subject.state.nodes.find! { |node| node.id == object.id } }

      it "changes time of last attempt" do
        expect{subject.perform}.to change{node.last_attempt_at}
      end

      it "does not change time of last success" do
        expect{subject.perform}.not_to change{node.last_success_at}
      end

      context "and a later reply" do
        let_create(:object, named: :reply4, in_reply_to_iri: object.iri)

        before_each { subject.perform }

        pre_condition { expect(horizon(subject)).not_to have(reply4.id) }

        it "adds the later reply to the horizon" do
          subject.perform
          expect(horizon(subject)).to have(reply4.id)
        end

        it "changes time of last attempt" do
          expect{subject.perform}.to change{node.last_attempt_at}
        end

        it "changes time of last success" do
          expect{subject.perform}.to change{node.last_success_at}
        end
      end
    end

    context "given a thread with many replies" do
      let_build(:object, named: :reply1, in_reply_to_iri: object.iri)
      let_build(:object, named: :reply2, in_reply_to_iri: object.iri)
      let_build(:object, named: :reply3, in_reply_to_iri: object.iri)
      let_build(:collection, named: :replies, iri: "#{object.iri}/replies", items_iris: [reply3.iri, reply2.iri, reply1.iri])

      before_each do
        HTTP::Client.objects << reply1
        HTTP::Client.objects << reply2
        HTTP::Client.objects << reply3
        HTTP::Client.actors << reply1.attributed_to
        HTTP::Client.actors << reply2.attributed_to
        HTTP::Client.actors << reply3.attributed_to
        HTTP::Client.objects << object.assign(replies_iri: replies.iri).save
        HTTP::Client.collections << replies
      end

      it "starts with cached objects in the horizon" do
        expect(horizon(subject)).to contain(object.id)
      end

      it "fetches the object" do
        subject.perform(1)
        expect(HTTP::Client.requests).to have("GET #{object.iri}")
      end

      it "fetches the collection" do
        subject.perform(1)
        expect(HTTP::Client.requests).to have("GET #{replies.iri}")
      end

      it "fetches a reply from the collection" do
        subject.perform(1)
        expect(HTTP::Client.requests).to have("GET #{reply3.iri}")
      end

      it "persists a reply from the collection" do
        expect{subject.perform(1)}.to change{find?(reply3.iri)}
      end

      it "does not change the thread value" do
        expect{subject.perform(1)}.not_to change{subject.thread}
      end

      it "adds a reply to the horizon" do
        subject.perform(1)
        expect(horizon(subject)).to contain(find(reply3.iri).id)
      end

      it "sets the next attempt in the immediate future" do
        subject.perform(1)
        expect(subject.next_attempt_at.not_nil!).to be < 1.minute.from_now
      end

      it "fetches the object" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{object.iri}")
      end

      it "fetches the collection once" do
        subject.perform
        expect(HTTP::Client.requests.count { |request| request === "GET #{replies.iri}"}).to eq(1)
      end

      it "fetches all the replies from the collection" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{reply3.iri}", "GET #{reply2.iri}", "GET #{reply1.iri}")
      end

      it "persists all the replies from the collection" do
        expect{subject.perform}.to change{ {find?(reply3.iri), find?(reply2.iri), find?(reply1.iri)}.any?(&.nil?) }.to(false)
      end

      it "does not change the thread value" do
        expect{subject.perform}.not_to change{subject.thread}
      end

      it "adds all the replies to the horizon" do
        subject.perform
        expect(horizon(subject)).to contain(find(reply3.iri).id, find(reply2.iri).id, find(reply1.iri).id)
      end

      it "sets the next attempt in the near future" do
        subject.perform
        expect(subject.next_attempt_at.not_nil!).to be_between(80.minutes.from_now, 160.minutes.from_now)
      end

      context "with all replies already fetched" do
        before_each { subject.perform }

        it "sets the next attempt in the far future" do
          subject.perform
          expect(subject.next_attempt_at.not_nil!).to be_between(170.minutes.from_now, 310.minutes.from_now)
        end

        # the following tests check to ensure prior behavior that was
        # reverted is not reintroduced.  we _do not_ want to check
        # collections more than once during a run, to avoid spamming
        # other sites. but, do ensure that new objects arriving via
        # ActivityPub are added to the horizon.

        context "and a later reply" do
          # an uncached reply
          let_build(:object, named: :reply4, id: 99999_i64, in_reply_to_iri: object.iri)

          before_each do
            HTTP::Client.objects << reply4
            HTTP::Client.actors << reply4.attributed_to
            HTTP::Client.collections << replies.assign(items_iris: [reply4.iri, reply3.iri, reply2.iri, reply1.iri])
            # normally set by the task worker
            subject.assign(last_attempt_at: reply4.created_at - 10.seconds)
          end

          pre_condition { expect(horizon(subject)).not_to have(reply4.id) }

          it "does not fetch the later reply" do
            subject.perform
            expect(HTTP::Client.requests).not_to have("GET #{reply4.iri}")
          end

          it "does not add the later reply to the horizon" do
            subject.perform
            expect(horizon(subject)).not_to contain(reply4.id)
          end

          it "sets the next attempt in the far future" do
            subject.perform
            expect(subject.next_attempt_at.not_nil!).to be_between(170.minutes.from_now, 310.minutes.from_now)
          end
        end

        context "and a later reply" do
          # a reply, but dereferenced and cached via some other process
          let_build(:object, named: :reply4, id: 99999_i64, in_reply_to_iri: object.iri)

          before_each do
            HTTP::Client.objects << reply4.save
            HTTP::Client.actors << reply4.attributed_to
            HTTP::Client.collections << replies.assign(items_iris: [reply4.iri, reply3.iri, reply2.iri, reply1.iri])
            # normally set by the task worker
            subject.assign(last_attempt_at: reply4.created_at - 10.seconds)
          end

          pre_condition { expect(horizon(subject)).not_to have(reply4.id) }

          it "fetches the later reply" do
            subject.perform
            expect(HTTP::Client.requests).to have("GET #{reply4.iri}")
          end

          it "adds the later reply to the horizon" do
            subject.perform
            expect(horizon(subject)).to contain(reply4.id)
          end

          it "sets the next attempt in the far future" do
            subject.perform
            expect(subject.next_attempt_at.not_nil!).to be_between(170.minutes.from_now, 310.minutes.from_now)
          end
        end
      end

      context "with some replies fetched" do
        subject do
          # test caching.
          # run and clear requests for that run.
          # return a wholly new instance!
          super.perform(1)
          super.save
          HTTP::Client.requests.clear
          described_class.find(super.id)
        end

        it "does not fetch the object" do
          subject.perform(2)
          expect(HTTP::Client.requests).not_to have("GET #{object.iri}")
        end

        it "does not fetch the collection" do
          subject.perform(2)
          expect(HTTP::Client.requests).not_to have("GET #{replies.iri}")
        end

        it "fetches the remaining replies from the collection" do
          subject.perform(2)
          expect(HTTP::Client.requests).to have("GET #{reply2.iri}", "GET #{reply1.iri}")
        end

        it "persists the remaining replies from the collection" do
          expect{subject.perform(2)}.to change{ {find?(reply2.iri), find?(reply1.iri)}.any?(&.nil?) }.to(false)
        end
      end
    end

    context "given a thread with uncached parents" do
      let_build(:object, named: :origin)
      let_build(:object, named: :reply1, in_reply_to_iri: origin.iri)
      let_build(:object, named: :reply2, in_reply_to_iri: reply1.iri)
      let_build(:object, named: :reply3, in_reply_to_iri: reply2.iri)
      let_create(:object, in_reply_to_iri: reply3.iri) # shadows earlier definition

      before_each do
        HTTP::Client.objects << origin
        HTTP::Client.objects << reply1
        HTTP::Client.objects << reply2
        HTTP::Client.objects << reply3
        HTTP::Client.actors << origin.attributed_to
        HTTP::Client.actors << reply1.attributed_to
        HTTP::Client.actors << reply2.attributed_to
        HTTP::Client.actors << reply3.attributed_to
      end

      it "starts with cached objects in the horizon" do
        expect(horizon(subject)).to contain(object.id)
      end

      it "fetches the nearest uncached object" do
        subject.perform(1)
        expect(HTTP::Client.requests).to have("GET #{reply3.iri}")
      end

      it "persists the nearest uncached object" do
        expect{subject.perform(1)}.to change{find?(reply3.iri)}
      end

      it "adds the nearest uncached object to the horizon" do
        subject.perform(1)
        expect(horizon(subject)).to contain(find(reply3.iri).id)
      end

      it "updates the thread value" do
        expect{subject.perform(1)}.to change{subject.thread}.to(reply3.in_reply_to_iri)
      end

      it "does not set the root object" do
        subject.perform(1)
        expect(subject.state.root_object).to be_nil
      end

      it "sets the next attempt in the immediate future" do
        subject.perform(1)
        expect(subject.next_attempt_at.not_nil!).to be < 1.minute.from_now
      end

      it "fetches all the uncached objects" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{reply3.iri}", "GET #{reply2.iri}", "GET #{reply1.iri}", "GET #{origin.iri}")
      end

      it "persists all the uncached objects" do
        expect{subject.perform}.to change{ {find?(reply3.iri), find?(reply2.iri), find?(reply1.iri), find?(origin.iri)}.any?(&.nil?) }.to(false)
      end

      it "adds all the uncached objects to the horizon" do
        subject.perform
        expect(horizon(subject)).to contain(find(reply3.iri).id, find(reply2.iri).id, find(reply1.iri).id, find(origin.iri).id)
      end

      it "updates the thread value" do
        expect{subject.perform}.to change{subject.thread}.to(origin.iri)
      end

      it "sets the root object" do
        subject.perform
        expect(subject.state.root_object).to eq(find(origin.iri).id)
      end

      it "sets the next attempt in the near future" do
        subject.perform
        expect(subject.next_attempt_at.not_nil!).to be_between(80.minutes.from_now, 160.minutes.from_now)
      end

      context "and uncached authors" do
        let(actor) { origin.attributed_to }
        let(actor1) { reply1.attributed_to }
        let(actor2) { reply2.attributed_to }
        let(actor3) { reply3.attributed_to }

        it "fetches all the uncached authors" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{actor3.iri}", "GET #{actor2.iri}", "GET #{actor1.iri}", "GET #{actor.iri}")
        end

        it "persists all the uncached authors" do
          expect{subject.perform}.to change{ {find?(actor3.iri), find?(actor2.iri), find?(actor1.iri), find?(actor.iri)}.any?(&.nil?) }.to(false)
        end
      end

      context "with an existing object" do
        before_each { reply2.save }

        it "does not fetch the object" do
          subject.perform
          expect(HTTP::Client.requests).not_to have("GET #{reply2.iri}")
        end

        it "fetches the other objects" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{reply3.iri}", "GET #{reply1.iri}", "GET #{origin.iri}")
        end

        context "that is deleted" do
          before_each { reply2.delete! }

          it "does not fetch the object" do
            subject.perform
            expect(HTTP::Client.requests).not_to have("GET #{reply2.iri}")
          end

          it "still fetches the other objects" do
            subject.perform
            expect(HTTP::Client.requests).to have("GET #{reply3.iri}", "GET #{reply1.iri}", "GET #{origin.iri}")
          end
        end

        context "that is blocked" do
          before_each { reply2.block! }

          it "does not fetch the object" do
            subject.perform
            expect(HTTP::Client.requests).not_to have("GET #{reply2.iri}")
          end

          it "still fetches the other objects" do
            subject.perform
            expect(HTTP::Client.requests).to have("GET #{reply3.iri}", "GET #{reply1.iri}", "GET #{origin.iri}")
          end
        end
      end

      context "with an unfetchable object" do
        before_each { HTTP::Client.objects.delete(reply2.iri) }

        it "fetches the object" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{reply2.iri}")
        end

        it "does not fetch following objects" do
          subject.perform
          expect(HTTP::Client.requests).not_to have("GET #{reply1.iri}", "GET #{origin.iri}")
        end

        it "fetches preceding objects" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{reply3.iri}")
        end
      end

      context "with all replies fetched" do
        before_each { subject.perform }

        it "sets the next attempt in the far future" do
          subject.perform
          expect(subject.next_attempt_at.not_nil!).to be_between(170.minutes.from_now, 310.minutes.from_now)
        end
      end
    end

    context "given a thread with pages of replies" do
      let_build(:object, named: :reply1, in_reply_to_iri: object.iri)
      let_build(:object, named: :reply2, in_reply_to_iri: object.iri)
      let_build(:object, named: :reply3, in_reply_to_iri: object.iri)

      before_each do
        HTTP::Client.objects << reply1
        HTTP::Client.objects << reply2
        HTTP::Client.objects << reply3
        HTTP::Client.objects << object.assign(replies_iri: "#{object.iri}/replies").save
        HTTP::Client.actors << reply1.attributed_to
        HTTP::Client.actors << reply2.attributed_to
        HTTP::Client.actors << reply3.attributed_to
        HTTP::Client.actors << object.attributed_to
      end

      context "organized by first and next" do
        let_build(:collection, named: :page2, iri: "#{object.iri}/replies?page=2", items_iris: [reply3.iri])
        let_build(:collection, named: :page1, iri: "#{object.iri}/replies?page=1", next_iri: "#{object.iri}/replies?page=2", items_iris: [reply2.iri, reply1.iri])
        let_build(:collection, iri: "#{object.iri}/replies", first_iri: "#{object.iri}/replies?page=1")

        before_each do
          HTTP::Client.collections << page2
          HTTP::Client.collections << page1
          HTTP::Client.collections << collection
        end

        it "fetches the collections" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{collection.iri}", "GET #{page1.iri}", "GET #{page2.iri}")
        end

        it "fetches the replies from the collections" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{reply2.iri}", "GET #{reply1.iri}", "GET #{reply3.iri}")
        end

        it "persists the replies" do
          expect{subject.perform}.to change{ {find?(reply2.iri), find?(reply1.iri), find?(reply3.iri)}.any?(&.nil?) }.to(false)
        end

        it "adds the replies to the horizon" do
          subject.perform
          expect(horizon(subject)).to contain(find(reply2.iri).id, find(reply1.iri).id, find(reply3.iri).id)
        end

        it "sets the next attempt in the near future" do
          subject.perform
          expect(subject.next_attempt_at.not_nil!).to be_between(80.minutes.from_now, 160.minutes.from_now)
        end
      end

      context "organized by last and prev" do
        let_build(:collection, named: :page2, iri: "#{object.iri}/replies?page=2", items_iris: [reply3.iri])
        let_build(:collection, named: :page1, iri: "#{object.iri}/replies?page=1", prev_iri: "#{object.iri}/replies?page=2", items_iris: [reply2.iri, reply1.iri])
        let_build(:collection, iri: "#{object.iri}/replies", last_iri: "#{object.iri}/replies?page=1")

        before_each do
          HTTP::Client.collections << page2
          HTTP::Client.collections << page1
          HTTP::Client.collections << collection
        end

        it "fetches the collections" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{collection.iri}", "GET #{page1.iri}", "GET #{page2.iri}")
        end

        it "fetches the replies from the collections" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{reply2.iri}", "GET #{reply1.iri}", "GET #{reply3.iri}")
        end

        it "persists the replies" do
          expect{subject.perform}.to change{ {find?(reply2.iri), find?(reply1.iri), find?(reply3.iri)}.any?(&.nil?) }.to(false)
        end

        it "adds the replies to the horizon" do
          subject.perform
          expect(horizon(subject)).to contain(find(reply2.iri).id, find(reply1.iri).id, find(reply3.iri).id)
        end

        it "sets the next attempt in the near future" do
          subject.perform
          expect(subject.next_attempt_at.not_nil!).to be_between(80.minutes.from_now, 160.minutes.from_now)
        end
      end
    end

    context "given a thread with Mastodon-style paging" do
      let_build(:object, named: :reply1, in_reply_to_iri: object.iri)
      let_build(:object, named: :reply2, in_reply_to_iri: object.iri)
      let_build(:object, named: :reply3, in_reply_to_iri: object.iri)
      let_build(:object, named: :reply4, in_reply_to_iri: reply1.iri)
      let_build(:object, named: :reply5, in_reply_to_iri: reply1.iri)
      let_build(:collection, named: :last_page1, iri: "#{object.iri}/replies?only_other_accounts=true&page=true", items_iris: [reply3.iri])
      let_build(:collection, named: :next_page1, iri: "#{object.iri}/replies?min_id=111535982952207180&page=true", next_iri: last_page1.iri, items_iris: [reply2.iri])
      let_build(:collection, named: :first_page1, items_iris: [reply1.iri], next_iri: next_page1.iri)
      let_build(:collection, named: :replies1, iri: "#{object.iri}/replies", first: first_page1)
      let_build(:collection, named: :next_page2, iri: "#{reply1.iri}/replies?only_other_accounts=true&page=true", items_iris: [reply5.iri])
      let_build(:collection, named: :first_page2, items_iris: [reply4.iri], next_iri: next_page2.iri)
      let_build(:collection, named: :replies2, iri: "#{reply1.iri}/replies", first: first_page2)

      before_each do
        HTTP::Client.objects << object.assign(replies_iri: replies1.iri).save
        HTTP::Client.objects << reply1.assign(replies_iri: replies2.iri)
        HTTP::Client.objects << reply2
        HTTP::Client.objects << reply3
        HTTP::Client.objects << reply4
        HTTP::Client.objects << reply5
        HTTP::Client.actors << object.attributed_to
        HTTP::Client.actors << reply1.attributed_to
        HTTP::Client.actors << reply2.attributed_to
        HTTP::Client.actors << reply3.attributed_to
        HTTP::Client.actors << reply4.attributed_to
        HTTP::Client.actors << reply5.attributed_to
        HTTP::Client.collections << last_page1
        HTTP::Client.collections << next_page1
        HTTP::Client.collections << replies1
        HTTP::Client.collections << next_page2
        HTTP::Client.collections << replies2
      end

      it "starts with cached objects in the horizon" do
        expect(horizon(subject)).to contain(object.id)
      end

      it "fetches the collections" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{replies1.iri}", "GET #{next_page1.iri}", "GET #{last_page1.iri}", "GET #{replies2.iri}", "GET #{next_page2.iri}")
      end

      it "fetches the replies from the collections" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{reply2.iri}", "GET #{reply1.iri}", "GET #{reply3.iri}", "GET #{reply4.iri}", "GET #{reply5.iri}")
      end

      it "persists the replies from the collections" do
        expect{subject.perform}.to change{ {find?(reply2.iri), find?(reply1.iri), find?(reply3.iri), find?(reply4.iri), find?(reply5.iri)} }
      end

      it "adds the replies from the collections to the horizon" do
        subject.perform
        expect(horizon(subject)).to contain(find(reply2.iri).id, find(reply1.iri).id, find(reply3.iri).id, find(reply4.iri).id)
      end

      it "does not update the thread value" do
        expect{subject.perform}.not_to change{subject.thread}
      end

      it "sets the next attempt in the near future" do
        subject.perform
        expect(subject.next_attempt_at.not_nil!).to be_between(80.minutes.from_now, 160.minutes.from_now)
      end

      context "with all replies fetched" do
        before_each { subject.perform}

        it "sets the next attempt in the far future" do
          subject.perform
          expect(subject.next_attempt_at.not_nil!).to be_between(170.minutes.from_now, 310.minutes.from_now)
        end
      end
    end
  end

  describe ".merge_into" do
    subject { described_class.new(**options).save }

    it "updates task if thread changes" do
      expect{described_class.merge_into(subject.thread, "https://new_thread")}.to change{subject.reload!.thread}.to("https://new_thread")
    end

    context "given an existing task for thread" do
      let_create!(:fetch_thread_task, named: existing, source: subject.source, thread: "https://new_thread")

      it "merges the tasks" do
        expect{described_class.merge_into(subject.thread, existing.thread)}.to change{described_class.count}.by(-1)
      end

      it "destroys the task which is merged from" do
        expect{described_class.merge_into(subject.thread, existing.thread)}.to change{described_class.find?(subject.id)}.to(nil)
      end

      it "does not destroy the task which is merged to" do
        expect{described_class.merge_into(subject.thread, existing.thread)}.not_to change{described_class.find?(existing.id)}
      end
    end
  end

  describe "#best_root" do
    let_build(:object, named: :root)
    let_create(:object, in_reply_to_iri: root.iri)

    subject do
      described_class.new(
        source: source,
        thread: object.thread
      ).save
    end

    it "returns the object" do
      expect(subject.best_root).to eq(object)
    end

    context "when the root it cached" do
      before_each { root.save }

      it "returns the root" do
        expect(subject.best_root).to eq(root)
      end
    end
  end

  describe "#path_to" do
    let_create(:object)

    subject do
      described_class.new(
        source: source,
        thread: object.thread
      ).save
    end

    it "returns the path to the thread page" do
      expect(subject.path_to).to eq("/remote/objects/#{object.id}/thread")
    end
  end
end

Spectator.describe Task::Fetch::Thread::State do
  subject { described_class.new }

  alias Node = Task::Fetch::Thread::State::Node

  let(node1) { Node.new(id: 1, last_attempt_at: 10.minutes.ago, last_success_at: 30.minutes.ago) }
  let(node2) { Node.new(id: 2, last_attempt_at: 10.minutes.ago, last_success_at: 40.minutes.ago) }
  let(node3) { Node.new(id: 3, last_attempt_at: 15.minutes.ago, last_success_at: 10.minutes.ago) }
  let(node4) { Node.new(id: 4, last_attempt_at: 15.minutes.ago, last_success_at: 20.minutes.ago) }

  before_each do
    subject.nodes = [node1, node2, node3, node4]
  end

  describe "#<<" do
    let(node) { Node.new(id: 0) }

    pre_condition { expect(subject.nodes).to contain_exactly(node1, node2, node3, node4) }

    it "returns the state instance" do
      expect(subject << node).to eq(subject)
    end

    it "appends the node" do
      expect((subject << node).nodes).to contain_exactly(node1, node2, node3, node4, node).in_any_order
    end
  end

  describe "#includes?" do
    it "returns true if nodes includes node" do
      expect(subject.includes?(Node.new(id: 1))).to be(true)
    end

    it "returns false if nodes does not include node" do
      expect(subject.includes?(Node.new(id: 0))).to be(false)
    end
  end

  describe "#prioritize!" do
    it "sorts objects by difference between last success and last attempt" do
      expect(subject.prioritize!).to eq([node3, node4, node1, node2])
    end
  end

  describe "#last_success_at" do
    it "returns the time of the most recent successful fetch" do
      expect(subject.last_success_at).to eq(node3.last_success_at)
    end
  end
end

Spectator.describe ActivityPub::Object do
  setup_spec

  context "given a task" do
    let_build(:object)
    let_build(:actor)
    let_create!(:fetch_thread_task, named: nil, source: actor, thread: object.save.thread)

    def all_fetches ; Task::Fetch::Thread.all end

    it "updates fetch tasks when thread changes" do
      expect{object.assign(in_reply_to_iri: "https://elsewhere").save}.to change{all_fetches.map(&.subject_iri)}.to(["https://elsewhere"])
    end

    context "given an existing fetch task" do
      let_create!(:fetch_thread_task, named: nil, source: actor, thread: "https://elsewhere")

      it "updates fetch tasks when thread changes" do
        expect{object.assign(in_reply_to_iri: "https://elsewhere").save}.to change{all_fetches.map(&.subject_iri)}.to(["https://elsewhere"])
      end
    end
  end
end
