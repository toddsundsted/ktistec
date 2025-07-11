require "../../../../src/models/task"
require "../../../../src/models/task/mixins/singleton"

require "../../../spec_helper/base"

class SingletonTask < Task
  include Task::Singleton

  def self.clear_instance
    @@instance = nil
  end

  def perform
    # no-op
  end
end

Spectator.describe Task::Singleton do
  setup_spec

  before_each { SingletonTask.clear_instance }

  describe ".instance" do
    it "returns the singleton instance" do
      expect(SingletonTask.instance).to be_a(SingletonTask)
    end
  end

  describe ".schedule_unless_exists" do
    it "creates a new instance" do
      expect { SingletonTask.schedule_unless_exists }.to change { SingletonTask.count }.by(1)
    end

    context "when an instance exists" do
      pre_condition { expect(SingletonTask.instance).not_to be_nil }

      it "does not create a new instance" do
        expect { SingletonTask.schedule_unless_exists }.not_to change { SingletonTask.count }
      end
    end
  end
end
