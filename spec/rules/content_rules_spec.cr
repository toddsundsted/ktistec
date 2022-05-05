require "../../src/rules/content_rules"

require "../spec_helper/factory"
require "../spec_helper/model"

alias Notification = Relationship::Content::Notification
alias Timeline = Relationship::Content::Timeline

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
  let_build(:object, attributed_to: owner)
  let_create(:create, actor: owner, object: object)
  let_create(:announce, actor: owner, object: object)
  let_create(:like, actor: owner, object: object)
  let_create(:follow, actor: owner, object: owner)
  let_create(:delete, actor: owner, object: object)
  let_create(:undo, actor: owner)

  subject { described_class.new }

  # notifications

  describe "#run" do
    def run(owner, activity)
      School::Fact.clear!
      School::Fact.assert(ContentRules::IsAddressedTo.new(activity, owner))
      subject.run(owner, activity)
    end

    context "given no notifications" do
      pre_condition { expect(owner.notifications).to be_empty }

      it "does not add the create to the notifications" do
        run(owner, create)
        expect(owner.notifications).to be_empty
      end

      it "adds the announce to the notifications" do
        run(owner, announce)
        expect(owner.notifications).to eq([announce])
      end

      it "adds the like to the notifications" do
        run(owner, like)
        expect(owner.notifications).to eq([like])
      end

      it "adds the follow to the notifications" do
        run(owner, follow)
        expect(owner.notifications).to eq([follow])
      end

      context "object mentions the owner" do
        before_each do
          object.assign(mentions: [
            Factory.build(:mention, name: owner.iri, href: owner.iri)
          ])
        end

        it "adds the create to the notifications" do
          run(owner, create)
          expect(owner.notifications).to eq([create])
        end
      end

      context "object mentions another actor" do
        before_each do
          object.assign(mentions: [
            Factory.build(:mention, name: other.iri, href: other.iri)
          ])
        end

        it "does not add the create to the notifications" do
          run(owner, create)
          expect(owner.notifications).to be_empty
        end
      end

      context "another object mentions the owner" do
        let_create!(:object, named: nil, mentions: [
          Factory.build(:mention, name: owner.iri, href: owner.iri)
        ])

        it "does not add the create to the notifications" do
          run(owner, create)
          expect(owner.notifications).to be_empty
        end
      end

      context "object is attributed to another actor" do
        before_each { object.assign(attributed_to: other) }

        it "does not add the announce to the notifications" do
          run(owner, announce)
          expect(owner.notifications).to be_empty
        end

        it "does not add the like to the notifications" do
          run(owner, like)
          expect(owner.notifications).to be_empty
        end

        context "another object is attributed to the owner" do
          let_create!(:object, named: nil, attributed_to: owner)

          it "does not add the announce to the notifications" do
            run(owner, announce)
            expect(owner.notifications).to be_empty
          end

          it "does not add the like to the notifications" do
            run(owner, like)
            expect(owner.notifications).to be_empty
          end
        end
      end

      context "follow does not follow the owner" do
        before_each { follow.assign(object: other).save }

        it "does not add the follow to the notifications" do
          run(owner, follow)
          expect(owner.notifications).to be_empty
        end
      end
    end

    context "given notifictions with create already added" do
      before_each do
        put_in_notifications(owner, create)
      end

      pre_condition { expect(owner.notifications).to eq([create]) }

      it "does not add the create to the notifications" do
        run(owner, create)
        expect(owner.notifications).to eq([create])
      end

      it "removes the create from the notifications" do
        run(owner, delete)
        expect(Notification.where(from_iri: owner.iri)).to be_empty
      end

      context "and an unrelated delete" do
        let_create(:delete, named: unrelated)

        it "does not remove the create from the notifications" do
          run(owner, unrelated)
          expect(owner.notifications).to eq([create])
        end
      end

      context "and an unrelated undo" do
        before_each { undo.assign(object: announce).save }

        it "does not remove the create from the notifications" do
          run(owner, undo)
          expect(owner.notifications).to eq([create])
        end
      end
    end

    context "given notifictions with announce already added" do
      before_each do
        undo.assign(object: announce).save
        put_in_notifications(owner, announce)
      end

      pre_condition { expect(owner.notifications).to eq([announce]) }

      it "does not add the announce to the notifications" do
        run(owner, announce)
        expect(owner.notifications).to eq([announce])
      end

      it "removes the announce from the notifications" do
        run(owner, undo)
        expect(Notification.where(from_iri: owner.iri)).to be_empty
      end

      it "does not remove the announce from the notifications" do
        run(owner, delete)
        expect(owner.notifications).to eq([announce])
      end
    end

    context "given notifictions with like already added" do
      before_each do
        undo.assign(object: like).save
        put_in_notifications(owner, like)
      end

      pre_condition { expect(owner.notifications).to eq([like]) }

      it "does not add the like to the notifications" do
        run(owner, like)
        expect(owner.notifications).to eq([like])
      end

      it "removes the like from the notifications" do
        run(owner, undo)
        expect(Notification.where(from_iri: owner.iri)).to be_empty
      end

      it "does not remove the like from the notifications" do
        run(owner, delete)
        expect(owner.notifications).to eq([like])
      end
    end

    context "given notifictions with follow already added" do
      before_each do
        undo.assign(object: follow).save
        put_in_notifications(owner, follow)
      end

      pre_condition { expect(owner.notifications).to eq([follow]) }

      it "does not add the follow to the notifications" do
        run(owner, follow)
        expect(owner.notifications).to eq([follow])
      end

      it "removes the follow from the notifications" do
        run(owner, undo)
        expect(Notification.where(from_iri: owner.iri)).to be_empty
      end

      it "does not remove the follow from the notifications" do
        run(owner, delete)
        expect(owner.notifications).to eq([follow])
      end
    end

    # currently, the following should never happen, but if the
    # activity has been undone, remove the corresponding notification.

    context "given notifications with an announce that has been undone" do
      before_each do
        undo.assign(object: announce).save
        put_in_notifications(owner, announce)
        announce.undo
      end

      pre_condition do
        expect(Notification.where(from_iri: owner.iri)).not_to be_empty
      end

      # a copy without the associations
      let(undo_fresh) { ActivityPub::Activity::Undo.find(undo.id) }

      it "removes the announce from the notifications" do
        run(owner, undo_fresh)
        expect(Notification.where(from_iri: owner.iri)).to be_empty
      end
    end
  end

  # timeline

  describe "#run" do
    def run(owner, activity)
      School::Fact.clear!
      School::Fact.assert(ContentRules::IsAddressedTo.new(activity, owner))
      subject.run(owner, activity)
    end

    context "given an empty timeline" do
      pre_condition { expect(owner.timeline).to be_empty }

      it "adds the object to the timeline" do
        run(owner, create)
        expect(owner.timeline).to eq([object])
      end

      it "adds the object to the timeline" do
        run(owner, announce)
        expect(owner.timeline).to eq([object])
      end

      context "object is a reply" do
        let_build(:object, named: :original, attributed_to: owner)

        before_each { object.in_reply_to = original }

        it "does not add the object to the timeline" do
          run(owner, create)
          expect(owner.timeline).to be_empty
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline).to eq([object])
        end
      end

      context "another object is a reply" do
        let_build(:object, named: :another, attributed_to: owner)

        before_each { another.in_reply_to = object }

        it "adds the object to the timeline" do
          run(owner, create)
          expect(owner.timeline).to eq([object])
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline).to eq([object])
        end
      end

      context "object mentions the owner" do
        before_each do
          object.assign(mentions: [
            Factory.build(:mention, name: owner.iri, href: owner.iri)
          ])
        end

        it "adds the object to the timeline" do
          run(owner, create)
          expect(owner.timeline).to eq([object])
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline).to eq([object])
        end
      end

      context "object mentions the owner and another actor" do
        before_each do
          object.assign(mentions: [
            Factory.build(:mention, name: owner.iri, href: owner.iri),
            Factory.build(:mention, name: other.iri, href: other.iri)
          ])
        end

        it "adds the object to the timeline" do
          run(owner, create)
          expect(owner.timeline).to eq([object])
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline).to eq([object])
        end
      end

      context "object mentions another actor" do
        before_each do
          object.assign(mentions: [
            Factory.build(:mention, name: other.iri, href: other.iri)
          ])
        end

        it "does not add the object to the timeline" do
          run(owner, create)
          expect(owner.timeline).to be_empty
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline).to eq([object])
        end
      end
    end

    context "given a timeline with an object already added" do
      before_each { put_in_timeline(owner, object) }

      pre_condition { expect(owner.timeline).to eq([object]) }

      context "and an associated create" do
        before_each { create }

        it "does not add the object to the timeline" do
          run(owner, create)
          expect(owner.timeline).to eq([object])
        end

        it "removes the object from the timeline" do
          run(owner, delete)
          expect(Timeline.where(from_iri: owner.iri)).to be_empty
        end

        context "and an unrelated delete" do
          let_create(:delete, named: unrelated)

          it "does not remove the object from the timeline" do
            run(owner, unrelated)
            expect(owner.timeline).to eq([object])
          end
        end

        context "and an unrelated undo" do
          before_each { undo.assign(object: announce).save }

          it "does not remove the object from the timeline" do
            run(owner, undo)
            expect(owner.timeline).to eq([object])
          end
        end
      end

      context "and an associated announce" do
        before_each { announce }

        it "does not add the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline).to eq([object])
        end

        it "removes the object from the timeline" do
          run(owner, delete)
          expect(Timeline.where(from_iri: owner.iri)).to be_empty
        end

        context "and a related undo" do
          before_each { undo.assign(object: announce).save }

          it "removes the object from the timeline" do
            run(owner, undo)
            expect(Timeline.where(from_iri: owner.iri)).to be_empty
          end

          context "and another announce" do
            let_create!(:announce, named: another, actor: owner, object: object)

            it "does not remove the object from the timeline" do
              run(owner, undo)
              expect(owner.timeline).to eq([object])
            end

            context "that has been undone" do
              before_each { another.undo }

              it "removes the object from the timeline" do
                run(owner, undo)
                expect(Timeline.where(from_iri: owner.iri)).to be_empty
              end
            end
          end
        end
      end
    end

    context "given a timeline with another object already added" do
      let_build(:object, named: another)

      before_each { put_in_timeline(owner, another) }

      pre_condition { expect(owner.timeline).to eq([another]) }

      it "does not remove the object from the timeline" do
        run(owner, delete)
        expect(owner.timeline).to eq([another])
      end

      it "does not remove the object from the timeline" do
        run(owner, undo)
        expect(owner.timeline).to eq([another])
      end
    end

    # currently, the following should never happen, but if the object
    # has been deleted, remove the corresponding timeline entry.

    context "given a timeline with an object that has been deleted" do
      before_each do
        put_in_timeline(owner, object)
        object.delete
      end

      pre_condition do
        expect(Timeline.where(from_iri: owner.iri)).not_to be_empty
      end

      # a copy without the associations
      let(delete_fresh) { ActivityPub::Activity::Delete.find(delete.id) }

      it "destroys the timeline entry" do
        run(owner, delete_fresh)
        expect(Timeline.where(from_iri: owner.iri)).to be_empty
      end
    end
  end
end
