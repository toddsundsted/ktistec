require "../../src/utils/avatar"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Utils::Avatar do
  setup_spec

  describe ".url_for" do
    context "when actor is nil" do
      it "returns fallback" do
        expect(described_class.url_for(nil)).to eq("/images/avatars/fallback.png")
      end
    end

    context "given an actor" do
      let_create(:actor, icon: "https://example.com/icon.png")

      it "returns the icon" do
        expect(described_class.url_for(actor)).to eq("https://example.com/icon.png")
      end

      let(color_avatar) { "/images/avatars/color-#{actor.id.not_nil! % 12}.png" }

      context "when icon is nil" do
        before_each { actor.assign(icon: nil).save }

        it "returns color avatar" do
          expect(described_class.url_for(actor)).to eq(color_avatar)
        end
      end

      context "when icon is blank" do
        before_each { actor.assign(icon: "").save }

        it "returns color avatar" do
          expect(described_class.url_for(actor)).to eq(color_avatar)
        end
      end

      context "when actor is down" do
        before_each { actor.down! }

        it "returns color avatar" do
          expect(described_class.url_for(actor)).to eq(color_avatar)
        end
      end

      context "when actor is deleted" do
        before_each { actor.delete! }

        it "returns deleted avatar" do
          expect(described_class.url_for(actor)).to eq("/images/avatars/deleted.png")
        end
      end

      context "when actor is blocked" do
        before_each { actor.block! }

        it "returns blocked avatar" do
          expect(described_class.url_for(actor)).to eq("/images/avatars/blocked.png")
        end
      end
    end
  end
end
