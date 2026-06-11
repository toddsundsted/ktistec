require "../../src/rules/content_rules"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe ContentRules do
  setup_spec

  {% if flag?(:"school:metrics") %}
    before_all do
      School::Metrics.reset
    end
    after_all do
      metrics = School::Metrics.metrics
      puts
      puts "runs:            #{metrics[:runs]}"
      puts "rules:           #{metrics[:rules]}"
      puts "conditions:      #{metrics[:conditions]}"
      puts "conditions/run:  #{metrics[:conditions_per_run]}"
      puts "conditions/rule: #{metrics[:conditions_per_rule]}"
      puts "operations:      #{metrics[:operations]}"
      puts "operations/run:  #{metrics[:operations_per_run]}"
      puts "operations/rule: #{metrics[:operations_per_rule]}"
      puts "runtime:         #{metrics[:runtime]}"
    end
  {% end %}

  describe ".new" do
    it "creates an instance" do
      expect(described_class.new).to be_a(ContentRules)
    end
  end

  let(owner) { register.actor }

  let_build(:actor, named: other)
  let_build(:object, attributed_to: other)
  let_create(:create, actor: other, object: object)
  let_create(:announce, actor: other, object: object)

  subject { described_class.new }

  # outbox

  describe "#run" do
    def run(owner, activity)
      subject.run do
        assert ContentRules::Outgoing.new(owner, activity)
      end
    end

    context "given an empty outbox" do
      pre_condition { expect(owner.in_outbox(public: false)).to be_empty }

      it "adds the activity to the outbox" do
        run(owner, create)
        expect(owner.in_outbox(public: false)).to eq([create])
      end
    end
  end

  # inbox

  describe "#run" do
    let(recipients) { [] of String }

    def run(owner, activity)
      subject.run do
        recipients.compact.each { |recipient| assert ContentRules::IsRecipient.new(recipient) }
        assert ContentRules::Incoming.new(owner, activity)
      end
    end

    context "given an empty inbox" do
      pre_condition { expect(owner.in_inbox(public: false)).to be_empty }

      it "does not add the activity to the inbox" do
        run(owner, create)
        expect(owner.in_inbox(public: false)).to be_empty
      end

      context "owner in recipients" do
        let(recipients) { [owner.iri] }

        it "adds the activity to the inbox" do
          run(owner, create)
          expect(owner.in_inbox(public: false)).to eq([create])
        end
      end

      context "public URL in recipients" do
        let(recipients) { ["https://www.w3.org/ns/activitystreams#Public"] }

        it "does not add the activity to the inbox" do
          run(owner, create)
          expect(owner.in_inbox(public: false)).to be_empty
        end

        context "and owner is follows activity's actor" do
          before_each do
            owner.follow(create.actor).save
          end

          it "adds the activity to the inbox" do
            run(owner, create)
            expect(owner.in_inbox(public: false)).to eq([create])
          end
        end
      end

      context "followers collection in recipients" do
        let(recipients) { [create.actor.followers] }

        it "does not add the activity to the inbox" do
          run(owner, create)
          expect(owner.in_inbox(public: false)).to be_empty
        end

        context "and owner is follows activity's actor" do
          before_each do
            owner.follow(create.actor).save
          end

          it "adds the activity to the inbox" do
            run(owner, create)
            expect(owner.in_inbox(public: false)).to eq([create])
          end
        end
      end
    end
  end

  # content filters / outgoing

  describe "#run" do
    def run(owner, activity)
      subject.run do
        assert ContentRules::Outgoing.new(owner, activity)
      end
    end

    before_each do
      create.assign(actor: owner).save
      announce.assign(actor: owner).save
    end

    context "given an empty outbox" do
      pre_condition { expect(owner.in_outbox(public: false)).to be_empty }

      it "adds the activity to the outbox" do
        run(owner, create)
        expect(owner.in_outbox(public: false)).to eq([create])
      end

      it "adds the activity to the outbox" do
        run(owner, announce)
        expect(owner.in_outbox(public: false)).to eq([announce])
      end

      context "given a content filter" do
        let_create!(:filter_term, term: "%content%")

        before_each do
          object.assign(content: "<span class='capitalize'>c</span>ontent blah blah").save
        end

        it "adds the activity to the outbox" do
          run(owner, create)
          expect(owner.in_outbox(public: false)).to eq([create])
        end

        it "adds the activity to the outbox" do
          run(owner, announce)
          expect(owner.in_outbox(public: false)).to eq([announce])
        end
      end

      context "given a content filter of the actor" do
        let_create!(:filter_term, actor: owner, term: "%content%")

        before_each do
          object.assign(content: "<span class='capitalize'>c</span>ontent blah blah").save
        end

        it "adds the activity to the outbox" do
          run(owner, create)
          expect(owner.in_outbox(public: false)).to eq([create])
        end

        it "adds the activity to the outbox" do
          run(owner, announce)
          expect(owner.in_outbox(public: false)).to eq([announce])
        end
      end
    end
  end

  # content filters / incoming

  describe "#run" do
    def run(owner, activity)
      subject.run do
        assert ContentRules::IsRecipient.new(owner.iri)
        assert ContentRules::Incoming.new(owner, activity)
      end
    end

    pre_condition do
      expect(create.actor).not_to eq(owner)
      expect(announce.actor).not_to eq(owner)
    end

    context "given an empty inbox" do
      pre_condition { expect(owner.in_inbox(public: false)).to be_empty }

      it "adds the activity to the inbox" do
        run(owner, create)
        expect(owner.in_inbox(public: false)).to eq([create])
      end

      it "adds the activity to the inbox" do
        run(owner, announce)
        expect(owner.in_inbox(public: false)).to eq([announce])
      end

      context "given a content filter" do
        let_create!(:filter_term, term: "%content%")

        before_each do
          object.assign(content: "<span class='capitalize'>c</span>ontent blah blah").save
        end

        it "adds the activity to the inbox" do
          run(owner, create)
          expect(owner.in_inbox(public: false)).to eq([create])
        end

        it "adds the activity to the inbox" do
          run(owner, announce)
          expect(owner.in_inbox(public: false)).to eq([announce])
        end
      end

      context "given a content filter of the actor" do
        let_create!(:filter_term, actor: owner, term: "%content%")

        before_each do
          object.assign(content: "<span class='capitalize'>c</span>ontent blah blah").save
        end

        it "does not add the activity to the inbox" do
          run(owner, create)
          expect(owner.in_inbox(public: false)).to be_empty
        end

        it "does not add the activity to the inbox" do
          run(owner, announce)
          expect(owner.in_inbox(public: false)).to be_empty
        end
      end
    end
  end
end
