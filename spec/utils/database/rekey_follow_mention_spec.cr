require "../../../src/utils/database/rekey_follow_mention"
require "../../../src/models/relationship/content/follow/mention"
require "../../../src/models/relationship/content/notification/follow/mention"
require "../../../src/models/tag/mention"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Ktistec::Database::RekeyFollowMention do
  setup_spec

  let(db) { Ktistec.database }

  let_create(:actor, named: owner)
  let_build(:object)

  describe ".run" do
    context "given a follow relationship" do
      let_create!(:follow_mention_relationship, named: follow, from_iri: owner.iri, to_iri: "foo@remote")

      it "drops it" do
        expect { described_class.run(db) }
          .to change { Relationship::Content::Follow::Mention.all.size }.from(1).to(0)
      end

      context "and a mention" do
        let_create!(:mention, named: nil, name: "foo@remote", href: "https://remote/users/foo", subject: object)

        it "re-keys it to the dominant href" do
          described_class.run(db)
          expect(Relationship::Content::Follow::Mention.all.map(&.to_iri)).to eq(["https://remote/users/foo"])
        end

        context "and a second follow for the same href" do
          let_create!(:mention, named: nil, name: "foo@other", href: "https://remote/users/foo", subject: object)
          let_create!(:follow_mention_relationship, named: nil, from_iri: owner.iri, to_iri: "foo@other")

          pre_condition { expect(Relationship::Content::Follow::Mention.all.size).to eq(2) }

          it "collapses them to the earliest row" do
            described_class.run(db)
            expect(Relationship::Content::Follow::Mention.all.map(&.id)).to eq([follow.id])
          end
        end
      end
    end

    context "given a notification relationship" do
      let_create!(:notification_follow_mention, named: notification, owner: owner, to_iri: "foo@remote")

      it "drops it" do
        expect { described_class.run(db) }
          .to change { Relationship::Content::Notification::Follow::Mention.all.size }.from(1).to(0)
      end

      context "and a mention" do
        let_create!(:mention, named: nil, name: "foo@remote", href: "https://remote/users/foo", subject: object)

        it "re-keys it to the dominant href" do
          described_class.run(db)
          expect(Relationship::Content::Notification::Follow::Mention.all.map(&.to_iri)).to eq(["https://remote/users/foo"])
        end

        context "and a second notification for the same href" do
          let_create!(:mention, named: nil, name: "foo@other", href: "https://remote/users/foo", subject: object)
          let_create!(:notification_follow_mention, named: nil, owner: owner, to_iri: "foo@other")

          pre_condition { expect(Relationship::Content::Notification::Follow::Mention.all.size).to eq(2) }

          it "collapses them to the earliest row" do
            described_class.run(db)
            expect(Relationship::Content::Notification::Follow::Mention.all.map(&.id)).to eq([notification.id])
          end
        end
      end
    end
  end

  describe ".revert" do
    let_create!(:mention, named: nil, name: "foo@remote", href: "https://remote/users/foo", subject: object)
    let_create!(:follow_mention_relationship, named: nil, from_iri: owner.iri, to_iri: "https://remote/users/foo")

    it "re-keys the href back to the dominant handle" do
      described_class.revert(db)
      expect(Relationship::Content::Follow::Mention.all.map(&.to_iri)).to eq(["foo@remote"])
    end
  end
end
