require "../../src/channels/model_channel"

require "../spec_helper/base"

Spectator.describe ModelChannel do
  setup_spec

  class TestModel
    include Ktistec::Model

    @@table_name = "models"

    @[Persistent]
    property invocations : Int32 = 0
  end

  before_each do
    Ktistec.database.exec <<-SQL
      CREATE TABLE IF NOT EXISTS models (
        id integer PRIMARY KEY AUTOINCREMENT,
        invocations integer
      )
    SQL
  end
  after_each do
    Ktistec.database.exec <<-SQL
      DROP TABLE IF EXISTS models
    SQL
  end

  let(model) { TestModel.new.save }

  subject { ModelChannel(TestModel).new }

  describe "#subscriptions" do
    it "returns the subscriptions" do
      expect(subject.subscriptions).to be_empty
    end
  end

  macro stop
    raise ModelChannel::Stop.new
  end

  describe "#subscribe" do
    pre_condition { expect(subject.subscriptions.size).to eq(0) }

    it "is invoked on timeout" do
      expect { subject.subscribe(model, timeout: 0.seconds) { model.invocations += 1; model.save; stop } }.to change { model.reload!.invocations }
    end

    it "receives updates about the model" do
      spawn { subject.publish(model) }
      expect { subject.subscribe(model) { model.invocations += 1; model.save; stop } }.to change { model.reload!.invocations }
    end
  end

  describe "#publish" do
    it "publishes an update but does not invoke any subscriptions" do
      expect { subject.publish(model) }.not_to change { model.reload!.invocations }
    end

    context "given a subscription" do
      before_each do
        spawn do
          subject.subscribe(model) { model.invocations += 1; model.save }
        rescue ex
        end
        Fiber.yield
      end

      pre_condition { expect(subject.subscriptions.size).to eq(1) }

      it "publishes an update" do
        subject.publish(model)
        expect { Fiber.yield }.to change { model.reload!.invocations }.by(1)
      end
    end

    context "given a different subscription" do
      before_each do
        spawn do
          subject.subscribe(TestModel.new.save) { model.invocations += 1; model.save }
        rescue ex
        end
        Fiber.yield
      end

      pre_condition { expect(subject.subscriptions.size).to eq(1) }

      it "does not publish an update" do
        subject.publish(model)
        expect { Fiber.yield }.not_to change { model.reload!.invocations }
      end
    end

    context "given a block that raises an error" do
      before_each do
        spawn do
          subject.subscribe(model) { raise "error" }
        rescue ex
        end
        Fiber.yield
      end

      pre_condition { expect(subject.subscriptions.size).to eq(1) }

      it "removes the subscription" do
        subject.publish(model)
        expect { Fiber.yield }.to change { subject.subscriptions.size }.to(0)
      end
    end

    context "given multiple updates" do
      before_each do
        spawn do
          subject.subscribe(model) { model.invocations += 1; model.save }
        rescue ex
        end
        Fiber.yield
      end

      pre_condition { expect(subject.subscriptions.size).to eq(1) }

      it "merges the updates" do
        subject.publish(model)
        subject.publish(model)
        expect { Fiber.yield }.to change { model.reload!.invocations }.by(1)
      end
    end
  end
end
