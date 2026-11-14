require "../../src/rules/view"
require "../../src/rules/view/feed"

require "../spec_helper/base"
require "../spec_helper/rule/view"

Spectator.describe Rules::View do
  preserve_view_registry

  let(view) { Rules::View::Feed.new(feed_id: 1_i64, owner_iri: "https://test.test/actors/owner", slug_or_id: "1") }

  describe ".register" do
    it "registers the view" do
      expect { Rules::View.register(view) }
        .to change { Rules::View.registry.includes?(view) }.from(false).to(true)
    end

    context "when a view of the same type is already registered" do
      before_each { Rules::View.register(view) }

      let(other) { Rules::View::Feed.new(feed_id: 1_i64, owner_iri: "https://test.test/actors/owner", slug_or_id: "feed") }

      it "does not register a duplicate" do
        expect { Rules::View.register(other) }
          .not_to change { Rules::View.registry.count(&.type.==(view.type)) }.from(1)
      end

      it "replaces the registered view" do
        expect { Rules::View.register(other) }
          .to change { Rules::View.registry.includes?(other) }.from(false).to(true)
      end
    end
  end

  describe ".unregister" do
    before_each { Rules::View.register(view) }

    pre_condition { expect(Rules::View.registry).to contain(view) }

    it "removes the registered view" do
      expect { Rules::View.unregister(view) }
        .to change { Rules::View.registry.includes?(view) }.from(true).to(false)
    end

    it "removes by type" do
      other = Rules::View::Feed.new(feed_id: 1_i64, owner_iri: "https://test.test/actors/owner", slug_or_id: "1")
      expect { Rules::View.unregister(other) }
        .to change { Rules::View.registry.includes?(view) }.from(true).to(false)
    end
  end
end
