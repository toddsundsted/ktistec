require "../../src/controllers/streaming"
require "../../src/services/feed/backend/criteria"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe StreamingController do
  setup_spec

  describe "GET /stream/mentions/:mention" do
    it "returns 401 if not authorized" do
      get "/stream/mentions/mention@example.com"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if the mention does not exist" do
        get "/stream/mentions/mention@example.com"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "GET /stream/tags/:hashtag" do
    it "returns 401 if not authorized" do
      get "/stream/tags/hashtag"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if the hashtag does not exist" do
        get "/stream/tags/hashtag"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "GET /stream/objects/:id" do
    it "returns 401 if not authorized" do
      get "/stream/objects/1"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if the object does not exist" do
        get "/stream/objects/999999"
        expect(response.status_code).to eq(404)
      end

      it "returns 400 if the id is not a number" do
        get "/stream/objects/foobar"
        expect(response.status_code).to eq(400)
      end
    end
  end

  describe "GET /stream/objects/:id/thread" do
    it "returns 401 if not authorized" do
      get "/stream/objects/1/thread"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if the object does not exist" do
        get "/stream/objects/999999/thread"
        expect(response.status_code).to eq(404)
      end

      it "returns 400 if the id is not a number" do
        get "/stream/objects/foobar/thread"
        expect(response.status_code).to eq(400)
      end
    end
  end

  describe "GET /stream/actors/:id" do
    it "returns 401 if not authorized" do
      get "/stream/actors/1"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if the actor does not exist" do
        get "/stream/actors/999999"
        expect(response.status_code).to eq(404)
      end

      it "returns 400 if the id is not a number" do
        get "/stream/actors/foobar"
        expect(response.status_code).to eq(400)
      end
    end
  end

  describe "GET /stream/actor/homepage" do
    it "returns 401 if not authorized" do
      get "/stream/actor/homepage"
      expect(response.status_code).to eq(401)
    end
  end

  describe "GET /stream/everything" do
    it "returns 401 if not authorized" do
      get "/stream/everything"
      expect(response.status_code).to eq(401)
    end
  end

  describe "GET /stream/actor/deck" do
    it "returns 401 if not authorized" do
      get "/stream/actor/deck"
      expect(response.status_code).to eq(401)
    end
  end

  describe ".encode_baselines" do
    it "encodes no baselines" do
      expect(described_class.encode_baselines(Hash(Int64, Int64).new)).to be_empty
    end

    it "encodes the baselines" do
      expect(described_class.encode_baselines({1_i64 => 1000_i64, 2_i64 => 2000_i64})).to eq("1:1000,2:2000")
    end
  end

  describe ".decode_baselines" do
    it "decodes an empty value" do
      expect(described_class.decode_baselines("")).to be_empty
    end

    it "decodes valid baselines" do
      expect(described_class.decode_baselines("1:1000,2:2000")).to eq({1_i64 => 1000_i64, 2_i64 => 2000_i64})
    end

    it "ignores invalid baselines" do
      expect(described_class.decode_baselines("1:1000,garbage")).to eq({1_i64 => 1000_i64})
    end
  end

  describe ".pane_advanced?" do
    let_create!(:feed, named: robotics)

    it "returns nil" do
      expect(described_class.pane_advanced?(robotics, nil)).to be_nil
    end

    context "given a post in the feed" do
      let(position) { Time.utc(2026, 1, 2) }

      let_create(:object, named: newer)

      before_each { put_in_feed(robotics, newer, at: position) }

      it "returns the position" do
        expect(described_class.pane_advanced?(robotics, nil)).to eq(position.to_unix_ms)
      end

      context "and a baseline before the position" do
        it "returns the position" do
          expect(described_class.pane_advanced?(robotics, position.to_unix_ms - 1)).to eq(position.to_unix_ms)
        end
      end

      context "and a baseline at the position" do
        it "returns nil" do
          expect(described_class.pane_advanced?(robotics, position.to_unix_ms)).to be_nil
        end
      end

      context "and an earlier post in the feed" do
        let(earlier) { Time.utc(2026, 1, 1) }

        let_create(:object, named: older)

        before_each { put_in_feed(robotics, older, at: earlier) }

        it "returns nil" do
          expect(described_class.pane_advanced?(robotics, position.to_unix_ms)).to be_nil
        end
      end
    end
  end

  describe ".open_deck" do
    let(actor) { register.actor }

    let_create!(:feed, named: robotics, owner: actor)

    let(feeds) { [robotics] }

    let(io) { IO::Memory.new }

    it "seeds the baseline at zero" do
      expect(described_class.open_deck(io, actor, feeds, nil)).to eq({robotics.id.not_nil! => 0_i64})
    end

    context "given a post in the feed" do
      let(position) { Time.utc(2026, 1, 2) }

      let_create(:object)

      before_each { put_in_feed(robotics, object, at: position) }

      context "on a fresh connection" do
        it "seeds the baseline at the position" do
          expect(described_class.open_deck(io, actor, feeds, nil)).to eq({robotics.id.not_nil! => position.to_unix_ms})
        end

        it "emits the baselines as the event id" do
          described_class.open_deck(io, actor, feeds, nil)
          expect(io.to_s).to contain("id: #{robotics.id}:#{position.to_unix_ms}")
        end

        it "does not notify" do
          described_class.open_deck(io, actor, feeds, nil)
          expect(io.to_s).not_to contain("Reload")
        end
      end

      context "on a reconnection at the position" do
        let(resume) { "#{robotics.id}:#{position.to_unix_ms}" }

        it "does not notify" do
          described_class.open_deck(io, actor, feeds, resume)
          expect(io.to_s).to be_empty
        end
      end

      context "on a reconnection before the position" do
        let(resume) { "#{robotics.id}:#{position.to_unix_ms - 1}" }

        it "advances the baseline" do
          expect(described_class.open_deck(io, actor, feeds, resume)).to eq({robotics.id.not_nil! => position.to_unix_ms})
        end

        it "notifies the pane" do
          described_class.open_deck(io, actor, feeds, resume)
          targets = io.to_s.scan(/target="([^"]+)"/).map(&.[1])
          expect(targets).to eq(["feed-#{robotics.id}-refresh"])
        end
      end
    end

    context "given two feeds holding the same post" do
      let(position) { Time.utc(2026, 1, 2) }

      let_create!(:feed, named: woodworking, owner: actor)

      let(feeds) { [robotics, woodworking] }

      let(resume) { "#{robotics.id}:#{position.to_unix_ms - 1},#{woodworking.id}:#{position.to_unix_ms - 1}" }

      let_create(:object)

      before_each do
        put_in_feed(robotics, object, at: position)
        put_in_feed(woodworking, object, at: position)
      end

      it "advances both baselines" do
        expect(described_class.open_deck(io, actor, feeds, resume)).to eq({robotics.id.not_nil! => position.to_unix_ms, woodworking.id.not_nil! => position.to_unix_ms})
      end

      it "notifies both panes" do
        described_class.open_deck(io, actor, feeds, resume)
        targets = io.to_s.scan(/target="([^"]+)"/).map(&.[1])
        expect(targets).to eq(["feed-#{robotics.id}-refresh", "feed-#{woodworking.id}-refresh"])
      end
    end
  end

  describe ".replace_actor_icon" do
    let_create(actor)

    subject do
      String.build do |io|
        described_class.replace_actor_icon(io, actor.id)
      end
    end

    it "renders a Turbo Stream action" do
      expect(subject).to eq <<-HTML
      data: \
      <turbo-stream action="replace" targets="img[data-actor-id='#{actor.id}']"><template>#{Ktistec::ViewHelper.actor_icon(actor, "ui avatar image", include_actor_id: false)}\
      </template></turbo-stream>
      \n
      HTML
    end

    context "given an icon that contains a double-quote" do
      before_each { actor.assign(icon: %(x" onerror="alert(1))).save }

      it "the sanitized attribute payload does not parse back as a new attribute" do
        parsed = XML.parse_html(
          "<div>#{subject}</div>",
          XML::HTMLParserOptions::RECOVER | XML::HTMLParserOptions::NODEFDTD | XML::HTMLParserOptions::NOIMPLIED,
        )
        expect(parsed.xpath_nodes("//img/@onerror")).to be_empty
      end
    end
  end

  describe ".replace_notifications_label" do
    let(account) { register }

    subject do
      String.build do |io|
        described_class.replace_notifications_label(io, account)
      end
    end

    context "given no notifications" do
      it "renders invisible labels" do
        expect(subject).to eq <<-HTML
      data: \
      <turbo-stream action="replace" targets=".ui.menu .mobile-menu-toggle .label"><template>\
      <span class="invisible label"></span>\
      </template></turbo-stream>

      data: \
      <turbo-stream action="replace" targets=".ui.menu .item.notifications .label"><template>\
      <span class="invisible label"></span>\
      </template></turbo-stream>
      \n
      HTML
      end
    end

    context "given a follow notification" do
      let_create!(notification_follow, owner: account.actor)

      it "renders red label with tooltip" do
        expect(subject).to eq <<-HTML
      data: \
      <turbo-stream action="replace" targets=".ui.menu .mobile-menu-toggle .label"><template>\
      <span class="ui mini transitional horizontal circular label red" title="follow 1">1</span>\
      </template></turbo-stream>

      data: \
      <turbo-stream action="replace" targets=".ui.menu .item.notifications .label"><template>\
      <span class="ui mini transitional horizontal circular label red" title="follow 1">1</span>\
      </template></turbo-stream>
      \n
      HTML
      end
    end

    context "given a like notification" do
      let_create!(notification_like, owner: account.actor)

      it "renders orange label with tooltip" do
        expect(subject).to eq <<-HTML
      data: \
      <turbo-stream action="replace" targets=".ui.menu .mobile-menu-toggle .label"><template>\
      <span class="ui mini transitional horizontal circular label orange" title="social 1">1</span>\
      </template></turbo-stream>

      data: \
      <turbo-stream action="replace" targets=".ui.menu .item.notifications .label"><template>\
      <span class="ui mini transitional horizontal circular label orange" title="social 1">1</span>\
      </template></turbo-stream>
      \n
      HTML
      end
    end
  end

  describe ".replace_refresh_posts_message" do
    subject do
      String.build do |io|
        described_class.replace_refresh_posts_message(io)
      end
    end

    it "renders a Turbo Stream action" do
      expect(subject).to eq <<-HTML
      data: \
      <turbo-stream action="replace" target="refresh-posts-message"><template>\
      <div id="refresh-posts-message" class="ui info icon message"><i class="sync icon"></i>\
      <div class="content"><div class="header">There are new posts!</div>\
      <p><a href="" data-turbo-prefetch="false" data-turbo-action="replace">Refresh</a></p>\
      </div></div>\
      </template></turbo-stream>
      \n
      HTML
    end
  end

  describe ".replace_pane_refresh" do
    let(account) { register }

    let_create!(:feed, named: robotics, owner: account.actor)

    subject do
      String.build do |io|
        described_class.replace_pane_refresh(io, account.actor, robotics)
      end
    end

    it "renders a Turbo Stream action" do
      expect(subject).to eq <<-HTML
      data: \
      <turbo-stream action="replace" target="feed-#{robotics.id}-refresh"><template>\
      <div id="feed-#{robotics.id}-refresh" class="pane-refresh">\
      <a class="ui small info icon message" href="/actors/#{account.username}/deck/panes/#{robotics.id}" data-turbo-prefetch="false" data-turbo-frame="feed-#{robotics.id}-pane">\
      <i class="sync icon"></i>\
      <div class="content">\
      <div class="header">There are new posts!</div>\
      <p>Reload this feed</p>\
      </div>\
      </a>\
      </div>\
      </template></turbo-stream>
      \n
      HTML
    end
  end

  describe ".setup_response" do
    subject do
      String.build do |io|
        response = HTTP::Server::Response.new(io)
        described_class.setup_response(response)
      end
    end

    it "sets Content-Type" do
      expect(subject.lines).to have("Content-Type: text/event-stream")
    end

    it "sets Cache-Control" do
      expect(subject.lines).to have("Cache-Control: no-cache")
    end

    it "sets X-Accel-Buffering" do
      expect(subject.lines).to have("X-Accel-Buffering: no")
    end
  end

  describe ".stream_action" do
    it "sends the body in a Turbo Stream / Server-Sent Events wrapper" do
      str = String.build do |io|
        described_class.stream_action(io, body: "<br>\n<br>\n<br>", action: "foobar", target: "target", selector: nil)
      end
      expect(str).to eq <<-HTML
      data: \
      <turbo-stream action="foobar" target="target"><template>\
      <br>
      data: <br>
      data: <br>\
      </template></turbo-stream>
      \n
      HTML
    end

    it "sends the body in a Turbo Stream / Server-Sent Events wrapper" do
      str = String.build do |io|
        described_class.stream_action(io, body: "<br>\n<br>\n<br>", action: "foobar", selector: "target", target: nil)
      end
      expect(str).to eq <<-HTML
      data: \
      <turbo-stream action="foobar" targets="target"><template>\
      <br>
      data: <br>
      data: <br>\
      </template></turbo-stream>
      \n
      HTML
    end

    it "sets the id" do
      str = String.build do |io|
        described_class.stream_action(io, body: nil, action: "foobar", id: "xyzzy", target: nil, selector: nil)
      end
      expect(str).to eq <<-HTML
      data: <turbo-stream action="foobar"></turbo-stream>
      id: xyzzy
      \n
      HTML
    end

    it "resets the id" do
      str = String.build do |io|
        described_class.stream_action(io, body: nil, action: "foobar", id: nil, target: nil, selector: nil)
      end
      expect(str).to eq <<-HTML
      data: <turbo-stream action="foobar"></turbo-stream>
      id
      \n
      HTML
    end
  end
end

Spectator.describe StreamingController::ConnectionPool do
  context "initialization" do
    it "creates a new pool" do
      pool = described_class.new(1)
      expect(pool).to be_a(described_class)
    end
  end

  describe "#capacity" do
    subject { described_class.new(1) }

    it "returns the capacity of the pool" do
      expect(subject.capacity).to eq(1)
    end
  end

  describe "#size" do
    subject { described_class.new(1) }

    it "returns the number of connections in the pool" do
      expect(subject.size).to eq(0)
    end
  end

  describe "#push" do
    subject { described_class.new(2) }

    let(connection) { IO::Memory.new }

    it "adds the connection to the pool" do
      subject.push(connection)
      expect(subject).to contain(connection)
    end

    context "given a pool at capacity" do
      before_each do
        subject.capacity.times do
          connection = IO::Memory.new
          subject.push(connection)
        end
      end

      pre_condition { expect(subject.size).to eq(2) }

      let(new_connection) { IO::Memory.new }

      it "adds the connection to the pool" do
        subject.push(new_connection)
        expect(subject).to contain(new_connection)
      end

      it "does not change the capacity of the pool" do
        expect { subject.push(new_connection) }.not_to change { subject.capacity }
      end

      it "does not change the size of the pool" do
        expect { subject.push(new_connection) }.not_to change { subject.size }
      end

      context "when a new connection is added" do
        let(removed) { subject.push(new_connection).not_nil! }

        it "removes the oldest connection from the pool" do
          expect(subject).not_to contain(removed)
        end

        it "closes the removed connection" do
          expect(removed.closed?).to be(true)
        end
      end
    end
  end
end

Spectator.describe ActivityPub::Object do
  setup_spec

  before_each { Ktistec::Topic.reset! }

  context "given a topic" do
    let_build(:object)
    let(topic) { Ktistec::Topic{object.iri, "foo/bar"} }

    it "updates subjects when thread changes" do
      expect { object.assign(in_reply_to_iri: "https://elsewhere").save }.to change { topic.subjects }.to(["https://elsewhere", "foo/bar"])
    end

    context "given an existing topic" do
      let!(existing) { Ktistec::Topic{"https://elsewhere"} }

      it "updates subjects when thread changes" do
        expect { object.assign(in_reply_to_iri: "https://elsewhere").save }.to change { topic.subjects }.to(["https://elsewhere", "foo/bar"])
      end
    end
  end
end
