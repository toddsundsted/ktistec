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
      subject! { described_class.new(**options).save }

      it "finds the existing task" do
        expect(described_class.find_or_new(**options)).to eq(subject)
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
      )
    end

    it "sets the next attempt at" do
      subject.perform
      expect(subject.next_attempt_at).not_to be_nil
    end

    def find_object?(iri)
      ActivityPub::Object.find?(iri)
    end

    def find_actor?(iri)
      ActivityPub::Actor.find?(iri)
    end

    context "a thread with uncached parents" do
      let_build(:object, named: :origin)
      let_build(:object, named: :reply1, in_reply_to_iri: origin.iri)
      let_build(:object, named: :reply2, in_reply_to_iri: reply1.iri)
      let_build(:object, named: :reply3, in_reply_to_iri: reply2.iri)

      before_each do
        HTTP::Client.objects << origin
        HTTP::Client.objects << reply1
        HTTP::Client.objects << reply2
        HTTP::Client.objects << reply3
        object.assign(in_reply_to_iri: reply3.iri).save
      end

      it "fetches the nearest uncached object" do
        subject.perform(1)
        expect(HTTP::Client.requests).to have("GET #{reply3.iri}")
      end

      it "persists the nearest uncached object" do
        expect{subject.perform(1)}.to change{find_object?(reply3.iri)}
      end

      it "updates the thread value" do
        expect{subject.perform(1)}.to change{subject.thread}.to(reply3.in_reply_to_iri)
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
        expect{subject.perform}.to change{ {find_object?(reply3.iri), find_object?(reply2.iri), find_object?(reply1.iri), find_object?(origin.iri)} }
      end

      it "updates the thread value" do
        expect{subject.perform}.to change{subject.thread}.to(origin.iri)
      end

      it "sets the next attempt in the near future" do
        subject.perform
        expect(subject.next_attempt_at.not_nil!).to be_between(10.minutes.from_now, 2.hours.from_now)
      end

      context "and uncached authors" do
        before_each do
          HTTP::Client.actors << origin.attributed_to
          HTTP::Client.actors << reply1.attributed_to
          HTTP::Client.actors << reply2.attributed_to
          HTTP::Client.actors << reply3.attributed_to
        end

        it "fetches all the uncached authors" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{reply3.attributed_to_iri}", "GET #{reply2.attributed_to_iri}", "GET #{reply1.attributed_to_iri}", "GET #{origin.attributed_to_iri}")
        end

        it "persists all the uncached authors" do
          expect{subject.perform}.to change{ {find_actor?(reply3.attributed_to_iri), find_actor?(reply2.attributed_to_iri), find_actor?(reply1.attributed_to_iri), find_actor?(origin.attributed_to_iri)} }
        end
      end

      context "given an existing object" do
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

      context "given an unfetchable object" do
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

      it "does not raise an error" do
        subject.perform
        subject.perform
      end
    end
  end

  describe ".merge_into" do
    subject { described_class.new(**options).save }

    it "updates task if thread changes" do
      expect{described_class.merge_into(subject.thread, "https://new_thread")}.to change{subject.reload!.thread}.to("https://new_thread")
    end

    context "given another task for thread" do
      let_create!(:fetch_thread_task, source: subject.source, thread: "https://new_thread")

      it "merges the tasks" do
        expect{described_class.merge_into(subject.thread, "https://new_thread")}.to change{described_class.count}.by(-1)
      end

      it "destroys the task which would be changed" do
        expect{described_class.merge_into(subject.thread, "https://new_thread")}.to change{described_class.find?(subject.id)}.to(nil)
      end
    end
  end
end
