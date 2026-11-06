require "../../../src/models/tag/label"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Tag::Label do
  setup_spec

  let_create(:actor, named: :owner, local: true)
  let_create(:object)

  context "validation" do
    it "rejects missing subject" do
      new_tag = described_class.new(owner: owner, subject_iri: "https://test.test/missing", name: "foo")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("subject")
    end

    it "rejects missing owner" do
      new_tag = described_class.new(href: "https://test.test/missing", subject: object, name: "foo")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("owner")
    end

    it "rejects blank name" do
      new_tag = described_class.new(owner: owner, subject: object, name: "")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("name")
    end

    context "given an existing label" do
      let_create!(:label, owner: owner, subject: object, name: "foo")

      it "rejects a duplicate" do
        new_tag = described_class.new(owner: owner, subject: object, name: "foo")
        expect(new_tag.valid?).to be_false
        expect(new_tag.errors.keys).to contain("name")
      end

      it "rejects a duplicate that includes a leading §" do
        new_tag = described_class.new(owner: owner, subject: object, name: "§foo")
        expect(new_tag.valid?).to be_false
        expect(new_tag.errors.keys).to contain("name")
      end

      it "remains valid" do
        expect(label.valid?).to be_true
      end

      context "and another owner" do
        let_create(:actor, named: :another, local: true)

        it "accepts the same name" do
          new_tag = described_class.new(owner: another, subject: object, name: "foo")
          expect(new_tag.valid?).to be_true
        end
      end

      context "and another subject" do
        let_create(:object, named: :another)

        it "accepts the same name" do
          new_tag = described_class.new(owner: owner, subject: another, name: "foo")
          expect(new_tag.valid?).to be_true
        end
      end
    end
  end

  describe "#save" do
    it "strips the leading §" do
      new_tag = described_class.new(owner: owner, subject: object, name: "§foo")
      expect { new_tag.save }.to change { new_tag.name }.from("§foo").to("foo")
    end

    it "leaves tag statistics unchanged" do
      new_tag = described_class.new(owner: owner, subject: object, name: "foo")
      expect { new_tag.save }.not_to change { Ktistec.database.scalar("SELECT count(*) FROM tag_statistics").as(Int64) }
    end
  end

  describe "#destroy" do
    let_create!(:label, owner: owner, subject: object, name: "foo")

    it "leaves tag statistics unchanged" do
      expect { label.destroy }.not_to change { Ktistec.database.scalar("SELECT count(*) FROM tag_statistics").as(Int64) }
    end
  end
end
