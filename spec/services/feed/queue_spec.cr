require "../../../src/services/feed/queue"
require "../../../src/services/feed/backend/criteria"
require "../../../src/models/task/feed/answer_questions"
require "../../../src/rules/feeds"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/feed/backend"
require "../../spec_helper/rule/view"

# Judges questions two at a time.
#
private class PairBackend < TestBackend
  def cost(params : Hash(String, JSON::Any)) : Cost
    Cost.new(batch_size: 2)
  end

  def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment | Failure)
    objects.map { Judgment.new(included: true).as(Judgment | Failure) }
  end

  def validate_params(params : Hash(String, JSON::Any)) : Array(String)
    [] of String
  end
end

Spectator.describe Feed::Queue do
  setup_spec

  let_create(:feed_version, named: version)

  let(object_iri) { "https://remote/objects/#{random_string}" }

  let(now) { Time.utc }

  def waiting
    Feed::Question.where(batched: false)
  end

  describe ".enqueue" do
    it "enqueues a question" do
      expect { Feed::Queue.enqueue(version.id!, object_iri, live: false) }
        .to change { waiting.size }.by(1)
    end

    it "is due now" do
      Feed::Queue.enqueue(version.id!, object_iri, live: false)
      expect(waiting.first.due_at).to be_close(now, delta: 1.second)
    end

    it "is due when scheduled" do
      Feed::Queue.enqueue(version.id!, object_iri, live: false, due_at: now + 1.hour)
      expect(waiting.first.due_at).to eq(now + 1.hour)
    end

    context "given a drain that is not yet due" do
      let!(drain) { Task::Feed::AnswerQuestions.new.assign(next_attempt_at: now + 1.hour).save }

      it "makes the drain due now" do
        Feed::Queue.enqueue(version.id!, object_iri, live: false)
        expect(drain.reload!.next_attempt_at.not_nil!).to be_close(now, delta: 1.second)
      end
    end

    context "given an existing question" do
      let_create!(:feed_question, named: existing, version: version, object_iri: object_iri, live: false, due_at: now - 10.minutes)

      it "does not enqueue another" do
        expect { Feed::Queue.enqueue(version.id!, object_iri, live: false) }
          .not_to change { waiting.size }.from(1)
      end

      it "keeps the existing question's time" do
        Feed::Queue.enqueue(version.id!, object_iri, live: false, due_at: now)
        expect(existing.reload!.due_at).to eq(now - 10.minutes)
      end

      it "adopts an earlier time" do
        Feed::Queue.enqueue(version.id!, object_iri, live: false, due_at: now - 1.hour)
        expect(existing.reload!.due_at).to eq(now - 1.hour)
      end

      context "and the new question is live" do
        pre_condition { expect(existing.live).to be_false }

        it "makes the existing question live" do
          Feed::Queue.enqueue(version.id!, object_iri, live: true, due_at: now - 1.minute)
          expect(existing.reload!.live).to be_true
        end

        it "adopts the live question's time" do
          Feed::Queue.enqueue(version.id!, object_iri, live: true, due_at: now - 1.minute)
          expect(existing.reload!.due_at).to eq(now - 1.minute)
        end

        it "keeps the earlier time" do
          Feed::Queue.enqueue(version.id!, object_iri, live: true, due_at: now + 1.hour)
          expect(existing.reload!.due_at).to eq(now - 10.minutes)
        end
      end

      context "that is live" do
        before_each { existing.assign(live: true).save }

        it "keeps the existing question live" do
          Feed::Queue.enqueue(version.id!, object_iri, live: false, due_at: now - 1.hour)
          expect(existing.reload!.live).to be_true
        end

        it "keeps the existing question's time" do
          Feed::Queue.enqueue(version.id!, object_iri, live: false, due_at: now - 1.hour)
          expect(existing.reload!.due_at).to eq(now - 10.minutes)
        end

        context "but is not due" do
          before_each { existing.assign(due_at: now + 1.hour).save }

          it "adopts the new question's time" do
            Feed::Queue.enqueue(version.id!, object_iri, live: false, due_at: now)
            expect(existing.reload!.due_at).to eq(now)
          end
        end
      end
    end

    context "given a batched question" do
      let_create!(:feed_question, version: version, object_iri: object_iri, batched: true)

      it "enqueues another" do
        expect { Feed::Queue.enqueue(version.id!, object_iri, live: false) }
          .to change { waiting.size }.by(1)
      end
    end

    context "given a question for another version" do
      let_create!(:feed_question, object_iri: object_iri)

      it "enqueues another" do
        expect { Feed::Queue.enqueue(version.id!, object_iri, live: false) }
          .to change { waiting.size }.by(1)
      end
    end

    context "given a waiting question and a batched question" do
      let_create!(:feed_question, named: nil)
      let_create!(:feed_question, named: nil, batched: true)

      pre_condition { expect(Feed::Question.count).to eq(Feed::Queue.backfill_cap) }

      it "does not count the question in a batch against the cap" do
        expect { Feed::Queue.enqueue(version.id!, object_iri, live: false) }
          .to change { waiting.size }.by(1)
      end
    end

    context "when the queue is at the backfill cap" do
      let_create!(:feed_question, named: question)
      let_create!(:feed_question, named: nil)

      pre_condition { expect(Feed::Question.count).to be >= Feed::Queue.backfill_cap }

      it "refuses a backfill question" do
        expect { Feed::Queue.enqueue(version.id!, object_iri, live: false) }
          .to raise_error(Feed::Queue::FullError)
      end

      it "accepts a backfill question it already holds" do
        expect { Feed::Queue.enqueue(question.version_id.not_nil!, question.object_iri.not_nil!, live: false) }
          .not_to raise_error
      end

      it "enqueues a live question" do
        expect { Feed::Queue.enqueue(version.id!, object_iri, live: true) }
          .to change { waiting.size }.by(1)
      end

      context "and at the live cap" do
        let_create!(:feed_question, named: nil, live: true)

        pre_condition { expect(Feed::Question.count).to be >= Feed::Queue.live_cap }

        it "refuses a live question" do
          expect { Feed::Queue.enqueue(version.id!, object_iri, live: true) }
            .to raise_error(Feed::Queue::FullError)
        end

        it "accepts a live question it already holds" do
          expect { Feed::Queue.enqueue(question.version_id.not_nil!, question.object_iri.not_nil!, live: true) }
            .not_to raise_error
        end
      end
    end
  end

  describe ".enqueue_backfill" do
    let_create!(:feed, owner: register.actor, draft: false, floor: KTISTEC_EPOCH)

    def questions
      Feed::Question.where(version_id: feed.version_id).sort_by!(&.id!)
    end

    def cover(low)
      Feed::Version.find(feed.version_id.not_nil!).assign(backfill_cursor: low).save
    end

    context "given candidates" do
      let_create!(:object, named: older)
      let_create!(:object, named: newer)

      it "enqueues the newest first" do
        Feed::Queue.enqueue_backfill(feed)
        expect(questions.map(&.object_iri)).to eq([newer.iri, older.iri])
      end

      it "reports that no candidates remain" do
        expect(Feed::Queue.enqueue_backfill(feed)).to be_false
      end

      it "enqueues only the newest" do
        Feed::Queue.enqueue_backfill(feed, limit: 1)
        expect(questions.map(&.object_iri)).to eq([newer.iri])
      end

      it "reports that candidates remain" do
        expect(Feed::Queue.enqueue_backfill(feed, limit: 1)).to be_true
      end

      it "enqueues questions as backfill" do
        Feed::Queue.enqueue_backfill(feed)
        expect(questions.map(&.live)).to eq([false, false])
      end

      it "enqueues questions as live" do
        Feed::Queue.enqueue_backfill(feed, live: true)
        expect(questions.map(&.live)).to eq([true, true])
      end

      context "and a page size larger than the candidates" do
        around_each do |proc|
          saved = Feed::Queue.page_size
          Feed::Queue.page_size = 3
          begin
            proc.call
          ensure
            Feed::Queue.page_size = saved
          end
        end

        it "covers the candidates it enqueued" do
          Feed::Queue.enqueue_backfill(feed)
          expect(Feed::Version.find(feed.version_id.not_nil!).backfill_cursor).to eq(older.id)
        end
      end

      context "and an earlier backfill that backfilled the newest" do
        before_each { cover(newer.id) }

        it "enqueues only the oldest" do
          Feed::Queue.enqueue_backfill(feed)
          expect(questions.map(&.object_iri)).to eq([older.iri])
        end
      end

      context "given more than will fit" do
        let_create!(:object, named: nil)

        it "covers only the candidates it enqueued" do
          Feed::Queue.enqueue_backfill(feed)
          expect(Feed::Version.find(feed.version_id.not_nil!).backfill_cursor).to eq(newer.id)
        end

        it "reports that candidates remain" do
          expect(Feed::Queue.enqueue_backfill(feed)).to be_true
        end
      end

      context "and a page already queued" do
        let_create!(:feed_question, version: feed.version, object: newer)

        before_each { cover(newer.id) }

        pre_condition { expect(questions.size).to eq(Feed::Queue.page_size) }

        it "enqueues nothing" do
          expect { Feed::Queue.enqueue_backfill(feed) }.not_to change { questions.size }
        end

        it "reports that candidates remain" do
          expect(Feed::Queue.enqueue_backfill(feed)).to be_true
        end
      end

      context "and a draft" do
        before_each { feed.assign(draft: true).save }

        it "enqueues the draft's candidates" do
          Feed::Queue.enqueue_backfill(feed)
          expect(questions.map(&.object_iri)).to eq([newer.iri, older.iri])
        end
      end

      context "and no floor" do
        before_each { feed.assign(floor: nil).save }

        it "enqueues nothing" do
          Feed::Queue.enqueue_backfill(feed)
          expect(questions).to be_empty
        end

        it "reports that no candidates remain" do
          expect(Feed::Queue.enqueue_backfill(feed)).to be_false
        end
      end

      context "given a drain that is not yet due" do
        let!(drain) { Task::Feed::AnswerQuestions.new.assign(next_attempt_at: now + 1.hour).save }

        it "makes the drain due now" do
          Feed::Queue.enqueue_backfill(feed)
          expect(drain.reload!.next_attempt_at.not_nil!).to be_close(now, delta: 1.second)
        end
      end
    end
  end

  describe ".enqueue_arrival" do
    preserve_view_registry

    let(actor) { register.actor }

    let_build(:object)
    let_create(:create, object: object)

    before_each { put_in_inbox(actor, create) }

    let_create!(:feed, owner: actor)

    def questions
      Feed::Question.where(version_id: feed.version_id, object_iri: object.iri)
    end

    it "enqueues nothing" do
      Feed::Queue.enqueue_arrival(object)
      expect(questions).to be_empty
    end

    context "when a feed is registered" do
      before_each { Rules::Feeds.register(feed) }

      it "enqueues a question" do
        Feed::Queue.enqueue_arrival(object)
        expect(questions.map(&.object_iri)).to eq([object.iri])
      end

      it "enqueues the question as live" do
        Feed::Queue.enqueue_arrival(object)
        expect(questions.map(&.live)).to eq([true])
      end

      context "and the object is not a candidate" do
        before_each { object.update_property(:published, nil) }

        pre_condition { expect(Feed::Candidates.arrival_for(feed, object)).to be_nil }

        it "enqueues nothing" do
          Feed::Queue.enqueue_arrival(object)
          expect(questions).to be_empty
        end
      end

      context "given a drain that is not yet due" do
        let!(drain) { Task::Feed::AnswerQuestions.new.assign(next_attempt_at: now + 1.hour).save }

        it "makes the drain due now" do
          Feed::Queue.enqueue_arrival(object)
          expect(drain.reload!.next_attempt_at.not_nil!).to be_close(now, delta: 1.second)
        end
      end
    end

    # creating each question saves a post, which arrives at any
    # registered feed, so register the feed after.
    context "when the queue is full" do
      let_create!(:feed_question, named: nil)
      let_create!(:feed_question, named: nil)
      let_create!(:feed_question, named: nil)

      pre_condition { expect(Feed::Question.count).to be >= Feed::Queue.live_cap }

      context "and a feed is registered" do
        before_each { Rules::Feeds.register(feed) }

        it "sheds the question" do
          Feed::Queue.enqueue_arrival(object)
          expect(questions).to be_empty
        end
      end
    end
  end

  describe ".pull" do
    it "pulls nothing" do
      expect(Feed::Queue.pull).to be_empty
    end

    context "given a question" do
      let_create!(:feed_question, named: earlier, version: version, due_at: now - 1.minute)

      it "pulls the question" do
        expect(Feed::Queue.pull.map(&.id)).to eq([earlier.id])
      end

      context "and a later question on the version" do
        let_create!(:feed_question, named: later, version: version, due_at: now - 1.second)

        it "pulls both questions" do
          expect(Feed::Queue.pull.map(&.id)).to contain_exactly(earlier.id, later.id).in_any_order
        end

        context "and a judge whose batch size is smaller than the waiting questions" do
          register_backend("pair", PairBackend.new)

          let_create(:feed_version, named: version, backend: "pair")
          let_create!(:feed_question, named: latest, version: version, due_at: now)

          it "pulls the first questions" do
            expect(Feed::Queue.pull.map(&.id)).to contain_exactly(earlier.id, later.id).in_any_order
          end
        end

        context "and an unregistered judge" do
          let_create(:feed_version, named: version, backend: "unregistered")

          it "pulls the question" do
            expect(Feed::Queue.pull.map(&.id)).to eq([earlier.id])
          end
        end
      end

      context "and a later question on another version" do
        let_create!(:feed_question, named: other, due_at: now - 1.second)

        it "pulls the question" do
          expect(Feed::Queue.pull.map(&.id)).to eq([earlier.id])
        end
      end
    end
  end

  describe ".finish" do
    let_create!(:feed_question)

    it "removes the question" do
      expect { Feed::Queue.finish(feed_question) }.to change { Feed::Question.count }.by(-1)
    end
  end

  describe ".release_batches" do
    let_create!(:feed_question, named: batched, version: version, object_iri: object_iri, due_at: now + 1.hour, batched: true)

    it "returns the question to waiting" do
      Feed::Queue.release_batches
      expect(waiting.map(&.object_iri)).to eq([object_iri])
    end

    it "leaves nothing in a batch" do
      Feed::Queue.release_batches
      expect(Feed::Question.where(batched: true)).to be_empty
    end

    it "keeps the question's time" do
      Feed::Queue.release_batches
      expect(waiting.map(&.due_at)).to eq([now + 1.hour])
    end

    context "when the question is live" do
      before_each { batched.assign(live: true).save }

      it "keeps the question live" do
        Feed::Queue.release_batches
        expect(waiting.map(&.live)).to eq([true])
      end
    end

    context "given a waiting question for the pair" do
      let_create!(:feed_question, named: nil, version: version, object_iri: object_iri)

      it "leaves only one question for the pair" do
        Feed::Queue.release_batches
        expect(Feed::Question.count(version_id: version.id, object_iri: object_iri)).to eq(1)
      end
    end

    context "when the queue is full" do
      let_create!(:feed_question, named: nil)
      let_create!(:feed_question, named: nil)

      pre_condition { expect(Feed::Question.count).to eq(Feed::Queue.live_cap) }

      it "returns the question to waiting" do
        Feed::Queue.release_batches
        expect(waiting.map(&.object_iri)).to contain(object_iri)
      end
    end
  end
end
