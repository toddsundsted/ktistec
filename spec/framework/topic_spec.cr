require "../../src/framework/topic"

require "../spec_helper/base"

Spectator.describe Ktistec::Topic do
  setup_spec

  before_each { described_class.clear_subscriptions! }

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
  end

  describe "#subscriptions" do
    it "returns the subscriptions" do
      expect(topic.subscriptions).to be_empty
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
end
