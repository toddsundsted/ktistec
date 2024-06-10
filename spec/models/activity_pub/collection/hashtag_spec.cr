require "../../../../src/models/activity_pub/collection/hashtag"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Collection::Hashtag do
  setup_spec

  describe ".find_or_create" do
    let_create!(:object)
    let_create!(:hashtag, subject: object, name: "hash/tag", href: "https://test.test/tags/hash%2Ftag")

    context "given an existing collection for hashtag" do
      let_create!(:collection, named: existing, iri: hashtag.href)

      it "finds the existing collection" do
        expect(ActivityPub::Collection::Hashtag.find_or_create(name: hashtag.name)).to eq(existing)
      end
    end
  end
end
