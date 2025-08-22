require "../../src/controllers/streaming"

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

  describe ".replace_actor_icon" do
    let_create(actor)

    subject do
      String.build do |io|
        described_class.replace_actor_icon(io, actor.id)
      end
    end

    it "renders a Turbo Stream action" do
      expect(subject).to eq <<-HTML
      data: <turbo-stream action="replace" targets=":is(i,img)[data-actor-id='#{actor.id}']">
      data: <template>
      data: <img src="#{actor.icon}">
      data: </template>
      data: </turbo-stream>
      \n
      HTML
    end
  end

  describe ".replace_notifications_count" do
    let(account) { register }
    let_create!(notification_follow, owner: account.actor)

    subject do
      String.build do |io|
        described_class.replace_notifications_count(io, account)
      end
    end

    it "renders a Turbo Stream action" do
      expect(subject).to eq <<-HTML
      data: <turbo-stream action="replace" targets=".ui.menu > .item.notifications">
      data: <template>
      data: <div class="item notifications">\
      <a class="ui" href="/actors/#{account.username}/notifications">Notifications</a>\
      <div class="ui mini transitional horizontal circular red label">1</div>\
      </div>
      data: </template>
      data: </turbo-stream>
      \n
      HTML
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
      data: <turbo-stream action="replace" target="refresh-posts-message">
      data: <template>
      data: <div id="refresh-posts-message" class="ui info icon message"><i class="sync icon"></i>\
      <div class="content"><div class="header">There are new posts!</div>\
      <p><a href="" data-turbo-prefetch="false" data-turbo-action="replace">Refresh</a></p>\
      </div></div>
      data: </template>
      data: </turbo-stream>
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
      data: <turbo-stream action="foobar" target="target">
      data: <template>
      data: <br>
      data: <br>
      data: <br>
      data: </template>
      data: </turbo-stream>
      \n
      HTML
    end

    it "sends the body in a Turbo Stream / Server-Sent Events wrapper" do
      str = String.build do |io|
        described_class.stream_action(io, body: "<br>\n<br>\n<br>", action: "foobar", selector: "target", target: nil)
      end
      expect(str).to eq <<-HTML
      data: <turbo-stream action="foobar" targets="target">
      data: <template>
      data: <br>
      data: <br>
      data: <br>
      data: </template>
      data: </turbo-stream>
      \n
      HTML
    end

    it "sets the id" do
      str = String.build do |io|
        described_class.stream_action(io, body: nil, action: "foobar", id: "xyzzy", target: nil, selector: nil)
      end
      expect(str).to eq <<-HTML
      data: <turbo-stream action="foobar">
      data: </turbo-stream>
      id: xyzzy
      \n
      HTML
    end

    it "resets the id" do
      str = String.build do |io|
        described_class.stream_action(io, body: nil, action: "foobar", id: nil, target: nil, selector: nil)
      end
      expect(str).to eq <<-HTML
      data: <turbo-stream action="foobar">
      data: </turbo-stream>
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
        subject.capacity.times do |i|
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
        expect{subject.push(new_connection)}.not_to change{subject.capacity}
      end

      it "does not change the size of the pool" do
        expect{subject.push(new_connection)}.not_to change{subject.size}
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
      expect{object.assign(in_reply_to_iri: "https://elsewhere").save}.to change{topic.subjects}.to(["https://elsewhere", "foo/bar"])
    end

    context "given an existing topic" do
      let!(existing) { Ktistec::Topic{"https://elsewhere"} }

      it "updates subjects when thread changes" do
        expect{object.assign(in_reply_to_iri: "https://elsewhere").save}.to change{topic.subjects}.to(["https://elsewhere", "foo/bar"])
      end
    end
  end
end
