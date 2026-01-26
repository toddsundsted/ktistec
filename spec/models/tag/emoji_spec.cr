require "../../../src/models/tag/emoji"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Tag::Emoji do
  setup_spec

  context "validation" do
    let_create(:object, local: true)

    it "rejects missing subject" do
      new_tag = described_class.new(subject_iri: "missing", name: "batman", href: "https://example.com/batman.png")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("subject")
    end

    it "rejects blank name" do
      new_tag = described_class.new(subject_iri: object.iri, name: "", href: "https://example.com/batman.png")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("name")
    end

    it "rejects blank href" do
      new_tag = described_class.new(subject_iri: object.iri, name: "batman", href: "")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("href")
    end
  end

  describe "#save" do
    let_create(:object, local: true)

    it "strips colons" do
      new_tag = described_class.new(subject_iri: object.iri, name: ":batman:", href: "https://example.com/batman.png")
      expect { new_tag.save }.to change { new_tag.name }.from(":batman:").to("batman")
    end

    it "strips leading and trailing whitespace" do
      new_tag = described_class.new(subject_iri: object.iri, name: "  :batman:  ", href: "https://example.com/batman.png")
      expect { new_tag.save }.to change { new_tag.name }.from("  :batman:  ").to("batman")
    end

    it "preserves case" do
      new_tag = described_class.new(subject_iri: object.iri, name: ":Batman:", href: "https://example.com/batman.png")
      expect { new_tag.save }.to change { new_tag.name }.from(":Batman:").to("Batman")
    end

    it "accepts name without colons" do
      new_tag = described_class.new(subject_iri: object.iri, name: "batman", href: "https://example.com/batman.png")
      expect(new_tag.save.name).to eq("batman")
    end
  end
end
