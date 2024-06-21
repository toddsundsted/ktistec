require "../../src/framework/topic"

require "../spec_helper/base"

Spectator.describe Ktistec::Topic do
  setup_spec

  before_each { described_class.reset! }

  describe "instantiation" do
    it "creates a new topic" do
      expect(described_class.new).to be_a(Ktistec::Topic)
    end

    it "creates a topic with no subjects" do
      expect(described_class.new.subjects).to be_empty
    end

    it "creates a topic with a subject" do
      expect(Ktistec::Topic{"subject"}.subjects).to eq(["subject"])
    end

    it "creates a topic with two subjects" do
      expect(Ktistec::Topic{"subject", "foobar"}.subjects).to eq(["subject", "foobar"])
    end
  end

  class ::Ktistec::Topic
    class Subjects
      def to_a
        @subjects.map_with_index { |subject, i| subject if @counts[i] > 0 }.compact
      end
    end

    class_getter subjects
  end

  describe "finalization" do
    let!(topic) { Ktistec::Topic{"subject"} }

    pre_condition { expect(described_class.subjects.to_a).to eq(["subject"]) }

    it "removes the topic's subjects" do
      topic.finalize
      expect(described_class.subjects.to_a).to be_empty
    end
  end

  macro make_subscription(topic, &block)
    before_each do
      spawn do
        {{topic}}.subscribe {{block}}
      rescue
      end
      Fiber.yield
    end
  end

  macro stop
    raise Ktistec::Topic::Stop.new
  end

  let(topic) { described_class.new }

  describe "#subjects" do
    it "returns the subjects of the topic" do
      expect(topic.subjects).to be_empty
    end

    context "given duplicate subjects" do
      let(topic) { Ktistec::Topic{"subject", "subject"} }

      it "returns each subject once" do
        expect(topic.subjects).to eq(["subject"])
      end
    end
  end

  describe "#subscriptions" do
    it "returns the subscriptions" do
      expect(topic.subscriptions).to be_empty
    end

    context "given a subscription" do
      let(topic) { Ktistec::Topic{"subject"} }

      make_subscription(topic) { }

      it "returns the subscriptions" do
        expect(topic.subscriptions).to have_key("subject")
      end
    end
  end

  describe "#<<" do
    it "adds a subject to the topic" do
      expect{topic << "subject"}.to change{topic.subjects}.to(["subject"])
    end

    context "given a subject and a subscription" do
      let(topic) { Ktistec::Topic{"subject"} }

      make_subscription(topic) { stop }

      it "raises an error" do
        expect{topic << "foobar"}.to raise_error(Ktistec::Topic::Error)
      end
    end

    context "given a subject and a notification" do
      before_each { topic.notify_subscribers }

      it "raises an error" do
        expect{topic << "subject"}.to raise_error(Ktistec::Topic::Error)
      end
    end
  end

  describe "#subscribe" do
    pre_condition { expect(topic.subscriptions.size).to eq(0) }

    it "is invoked on timeout" do
      invocations = 0
      expect{topic.subscribe(timeout: 0.seconds) { invocations += 1 ; stop } }.to change{invocations}.to(1)
    end

    context "given a subject and a pending notification" do
      let(topic) { Ktistec::Topic{"subject"} }

      before_each { spawn { topic.notify_subscribers } }

      it "receives updates" do
        invocations = 0
        expect{topic.subscribe { invocations += 1 ; stop } }.to change{invocations}.to(1)
      end
    end
  end

  describe "#notify_subscribers" do
    let(topic) { Ktistec::Topic{"subject"} }

    it "does not block" do
      topic.notify_subscribers
    end

    let(invocations) { [0] }

    context "given a subscription" do
      make_subscription(topic) { self.invocations[0] += 1 }

      pre_condition { expect(topic.subscriptions.size).to eq(1) }

      it "notifies the subscriber" do
        topic.notify_subscribers
        expect{Fiber.yield}.to change{invocations[0]}.by(1)
      end

      it "notifies the subscriber" do
        topic.notify_subscribers
        expect{Fiber.yield}.to change{invocations[0]}.to(1)
        topic.notify_subscribers
        expect{Fiber.yield}.to change{invocations[0]}.to(2)
      end

      it "merges the notifications" do
        topic.notify_subscribers
        topic.notify_subscribers
        expect{Fiber.yield}.to change{invocations[0]}.by(1)
      end
    end

    context "given a different subject" do
      make_subscription(Ktistec::Topic{"foobar"}) { self.invocations[0] += 1 }

      pre_condition { expect(topic.subscriptions.size).to eq(0) }

      it "does not notify the subscriber" do
        topic.notify_subscribers
        expect{Fiber.yield}.not_to change{invocations[0]}.from(0)
      end

      context "that is renamed" do
        before_each do
          topic # ensure `topic` is created before the rename happens
          Ktistec::Topic.rename_subject("foobar", "subject")
        end

        pre_condition { expect(Ktistec::Topic.subjects.size).to eq(2) }

        it "notifies the subscriber" do
          topic.notify_subscribers
          expect{Fiber.yield}.to change{invocations[0]}.by(1)
        end
      end
    end

    context "given the same subject" do
      make_subscription(Ktistec::Topic{"subject"}) { self.invocations[0] += 1 }

      pre_condition { expect(topic.subscriptions.size).to eq(1) }

      it "notifies the subscriber" do
        topic.notify_subscribers
        expect{Fiber.yield}.to change{invocations[0]}.by(1)
      end
    end

    context "given a block that raises an error" do
      make_subscription(topic) { raise "error" }

      pre_condition { expect(topic.subscriptions.size).to eq(1) }

      it "removes the subscription" do
        topic.notify_subscribers
        expect{Fiber.yield}.to change{topic.subscriptions.size}.to(0)
      end
    end
  end

  describe ".rename_subject" do
    let!(topic) { Ktistec::Topic{"subject"} }

    it "renames the subject" do
      expect{described_class.rename_subject("subject", "foobar")}.to change{topic.subjects}.from(["subject"]).to(["foobar"])
    end

    it "renames the subject" do
      expect{described_class.rename_subject("subject", "foobar")}.to change{described_class.subjects.to_a}.from(["subject"]).to(["foobar"])
    end
  end
end

Spectator.describe Ktistec::Topic::Subjects do
  describe "#map" do
    it "maps a value to the next storage location" do
      expect(subject.map("one")).to eq(0)
      expect(subject.map("two")).to eq(1)
    end

    context "given existings mappings" do
      before_each do
        subject.map("one")
        subject.map("two")
      end

      it "retrieves the storage location of existing mappings" do
        expect(subject.map("one")).to eq(0)
        expect(subject.map("two")).to eq(1)
      end

      it "maps a new value to the next storage location" do
        expect(subject.map("three")).to eq(2)
      end

      context "that are cleared" do
        before_each do
          subject.clear(0)
          subject.clear(1)
        end

        it "reuses the storage locations of cleared mappings" do
          expect(subject.map("three")).to eq(0)
          expect(subject.map("four")).to eq(1)
        end
      end
    end
  end

  describe "#unmap" do
    before_each do
      subject.map("one")
      subject.map("two")
    end

    it "unmaps values from their storage locations" do
      expect{subject.unmap(0)}.to change{subject[0]}.from("one").to(nil)
      expect{subject.unmap(1)}.to change{subject[1]}.from("two").to(nil)
    end

    it "raises an error if the storage location is not mapped" do
      expect{subject.unmap(2)}.to raise_error
    end

    context "when mapped more than once" do
      before_each do
        subject.map("one")
        subject.map("two")
      end

      it "does not unmap values from their storage locations" do
        expect{subject.unmap(0)}.not_to change{subject[0]}.from("one")
        expect{subject.unmap(1)}.not_to change{subject[1]}.from("two")
      end

      context "and unmapped once" do
        before_each do
          subject.unmap(0)
          subject.unmap(1)
        end

        it "unmaps values from their storage locations" do
          expect{subject.unmap(0)}.to change{subject[0]}.from("one").to(nil)
          expect{subject.unmap(1)}.to change{subject[1]}.from("two").to(nil)
        end
      end
    end
  end

  describe "#clear" do
    before_each do
      subject.map("one")
      subject.map("two")
    end

    it "clears the storage locations" do
      expect{subject.clear(0)}.to change{subject[0]}.from("one").to(nil)
      expect{subject.clear(1)}.to change{subject[1]}.from("two").to(nil)
    end

    it "raises an error if the storage location is not mapped" do
      expect{subject.clear(2)}.to raise_error
    end
  end

  describe "#[]" do
    before_each do
      subject.map("one")
      subject.map("two")
    end

    it "retrieves the value at the storage location" do
      expect(subject[0]).to eq("one")
      expect(subject[1]).to eq("two")
    end

    it "raises an error if the storage location is not mapped" do
      expect{subject[2]}.to raise_error
    end
  end
end
