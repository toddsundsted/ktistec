require "../../src/rules/feeds"
require "../../src/services/feed/backend/criteria"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Rules::Feeds do
  setup_spec

  around_each do |proc|
    saved = Rules::View.registry.dup
    begin
      proc.call
    ensure
      Rules::View.registry.clear
      Rules::View.registry.concat(saved)
    end
  end

  let(actor) { register.actor }

  let_create!(:feed, owner: actor)

  describe ".view_for" do
    it "returns the feed's view" do
      view = Rules::Feeds.view_for(feed)
      expect(view.type).to eq(feed.feed_type)
      expect(view.owner_iri).to eq(actor.iri)
    end
  end

  describe ".register_all" do
    let_create!(:feed, named: other, owner: actor)

    it "registers a view per feed" do
      expect { Rules::Feeds.register_all }
        .to change { Rules::View.registry.select(Rules::View::Feed).map(&.type).sort! }
          .from([] of String).to([feed.feed_type, other.feed_type].sort)
    end
  end

  describe ".register" do
    it "registers the feed's view" do
      expect { Rules::Feeds.register(feed) }
        .to change { Rules::View.registry.select(Rules::View::Feed).map(&.type) }
          .from([] of String).to([feed.feed_type])
    end
  end

  describe ".unregister" do
    before_each { Rules::Feeds.register(feed) }

    it "unregisters the feed's view" do
      expect { Rules::Feeds.unregister(feed) }
        .to change { Rules::View.registry.select(Rules::View::Feed).map(&.type) }
          .from([feed.feed_type]).to([] of String)
    end
  end
end
