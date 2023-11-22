require "../../../src/models/task/update_metrics"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::UpdateMetrics do
  setup_spec

  describe "#last_id" do
    subject { described_class.new }

    it "retrieves the last id value from the state" do
      subject.state = Task::UpdateMetrics::State.new(99_i64)
      expect(subject.last_id).to eq(99_i64)
    end
  end

  describe "#last_id=" do
    subject { described_class.new }

    it "stores the last id value in the state" do
      subject.last_id = 99_i64
      expect(subject.state.last_id).to eq(99_i64)
    end
  end

  describe ".schedule_unless_exists" do
    it "schedules a new task" do
      expect{described_class.schedule_unless_exists}.to change{described_class.count}.by(1)
    end

    context "given an existing task" do
      before_each { described_class.new.schedule }

      it "does not schedule a new task" do
        expect{described_class.schedule_unless_exists}.not_to change{described_class.count}
      end
    end
  end

  describe "#perform" do
    subject { described_class.new }

    it "sets the next attempt at" do
      subject.perform
      expect(subject.next_attempt_at).not_to be_nil
    end

    context "given items in the inbox" do
      let(account) { register }
      let(owner) { account.actor }

      macro create_item(index)
        let_create!(
          :inbox_relationship, named: inbox{{index}},
          owner: owner,
          created_at: Time.utc(2016, 2, {{index}}, 10, 20, 30)
        )
      end

      create_item(1)
      create_item(2)
      create_item(3)
      create_item(4)
      create_item(5)

      let(inbox) { "inbox-#{account.username}" }

      it "creates points" do
        expect{subject.perform}.to change{Point.count}.by(5)
        expect(Point.chart(inbox).map(&.value)).to eq([1, 1, 1, 1, 1])
      end

      it "accumulates points for activities on the same day" do
        inbox5.assign(created_at: Time.utc(2016, 2, 4, 10, 10, 10)).save
        expect{subject.perform}.to change{Point.count}.by(4)
        expect(Point.chart(inbox).map(&.value)).to eq([1, 1, 1, 2])
      end

      it "accumulates points in the timezone of the account" do
        account.assign(timezone: "Etc/GMT+8").save
        inbox5.assign(created_at: Time.utc(2016, 2, 5, 4, 10, 10)).save
        expect{subject.perform}.to change{Point.count}.by(4)
        expect(Point.chart(inbox).map(&.value)).to eq([1, 1, 1, 2])
      end

      it "creates points for activities created since the last run" do
        subject.last_id = inbox3.id
        expect{subject.perform}.to change{Point.count}.by(2)
        expect(Point.chart(inbox).map(&.value)).to eq([1, 1])
      end

      context "point already exists" do
        let_create!(:point, chart: inbox, timestamp: Time.utc(2016, 2, 5, 0, 0, 0), value: 2)

        it "increments point value" do
          expect{subject.perform}.to change{Point.count}.by(4)
          expect(Point.chart(inbox).map(&.value)).to eq([1, 1, 1, 1, 3])
        end
      end

      it "sets the last_id" do
        subject.perform
        expect(subject.last_id).to eq(inbox5.id)
      end
    end
  end
end
