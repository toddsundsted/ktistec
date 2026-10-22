require "../../src/serializers/post"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Serializers::Post do
  setup_spec

  describe ".from" do
    let_build(:object, content: "<p>A cat</p>")

    subject { described_class.from(object) }

    it "carries the post's IRI" do
      expect(subject.iri).to eq(object.iri)
    end

    it "carries the post's content" do
      expect(subject.content).to eq("<p>A cat</p>")
    end
  end
end
