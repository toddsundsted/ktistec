require "../../src/rules/view"
require "../../src/rules/view/feed"

require "../spec_helper/base"

Spectator.describe Rules::View do
  around_each do |proc|
    saved = Rules::View.registry.dup
    begin
      proc.call
    ensure
      Rules::View.registry.clear
      Rules::View.registry.concat(saved)
    end
  end

  let(view) { Rules::View::Feed.new(feed_id: 1_i64, owner_iri: "https://test.test/actors/owner") }

  describe ".register" do
    it "registers the view" do
      expect { Rules::View.register(view) }
        .to change { Rules::View.registry.includes?(view) }.from(false).to(true)
    end

    context "when a view of the same type is already registered" do
      before_each { Rules::View.register(view) }

      it "does not register a duplicate" do
        other = Rules::View::Feed.new(feed_id: 1_i64, owner_iri: "https://test.test/actors/owner")
        expect { Rules::View.register(other) }
          .not_to change { Rules::View.registry.count(&.type.==(view.type)) }.from(1)
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
      other = Rules::View::Feed.new(feed_id: 1_i64, owner_iri: "https://test.test/actors/owner")
      expect { Rules::View.unregister(other) }
        .to change { Rules::View.registry.includes?(view) }.from(true).to(false)
    end
  end
end
