require "../../../src/services/feed/queue"
require "../../../src/services/feed/backend/criteria"
require "../../../src/rules/feeds"

require "../../spec_helper/base"
require "../../spec_helper/factory"

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

    context "given candidates" do
      let_create!(:object, named: older)
      let_create!(:object, named: newer)

      it "enqueues the newest first" do
        Feed::Queue.enqueue_backfill(feed)
        expect(questions.map(&.object_iri)).to eq([newer.iri, older.iri])
      end

      it "enqueues only the newest" do
        Feed::Queue.enqueue_backfill(feed, limit: 1)
        expect(questions.map(&.object_iri)).to eq([newer.iri])
      end

      it "enqueues questions as backfill" do
        Feed::Queue.enqueue_backfill(feed)
        expect(questions.map(&.live)).to eq([false, false])
      end

      it "enqueues questions as live" do
        Feed::Queue.enqueue_backfill(feed, live: true)
        expect(questions.map(&.live)).to eq([true, true])
      end

      context "given more than will fit" do
        let_create!(:object, named: nil)

        it "sheds questions that won't fit" do
          Feed::Queue.enqueue_backfill(feed)
          expect(questions.size).to eq(Feed::Queue.backfill_cap)
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
      end
    end
  end

  describe ".enqueue_arrival" do
    around_each do |proc|
      saved = Rules::View.registry.dup
      begin
        proc.call
      ensure
        Rules::View.registry.clear
        Rules::View.registry.concat(saved)
      end
    end

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
    let_create!(:feed_question, version: version, due_at: now - 1.minute)

    it "pulls the question" do
      expect(Feed::Queue.pull.try(&.id)).to eq(feed_question.id)
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
