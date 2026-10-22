require "../../../../../src/services/feed/backend/executable/exchange"

require "../../../../spec_helper/base"
require "../../../../spec_helper/factory"

Spectator.describe Feed::Backend::Executable::Exchange do
  setup_spec

  let(path) { File.tempname("ktistec", "exchange") }

  after_each { File.delete?(path) }

  let_build(:feed, name: "Cats", description: "Posts about cats", params: JSON.parse(%({"topic":"cats"})).as_h)

  let(attachment) { ActivityPub::Object::Attachment.new("https://remote/cat.jpg", "image/jpeg", "A cat") }
  let_build(:hashtag, name: "cats", href: "https://remote/tags/cats")
  let_build(:mention, name: "alice@remote", href: "https://remote/actors/alice")
  let_build(
    :object,
    name: "Cats",
    summary: "<p>About a cat</p>",
    content: "<p>A cat</p>",
    audience: ["https://remote/c/cats"],
    attachments: [attachment],
    published: Time.utc(2026, 10, 22, 12, 0, 0),
    in_reply_to_iri: "https://remote/objects/parent",
    thread: "https://remote/objects/root",
    quote_iri: "https://remote/objects/quoted",
    language: "en",
    sensitive: true,
    hashtags: [hashtag],
    mentions: [mention],
  )

  describe ".write" do
    let(now) { Time.utc(2026, 10, 23) }

    let_create!(:follow_relationship, actor: feed.owner, object: object.attributed_to, confirmed: true)
    let_create!(:object, named: nil, attributed_to: object.attributed_to, published: now - 1.day)

    def query(sql, as types)
      DB.open("sqlite3://#{path}", &.query_one(sql, as: types))
    end

    it "records the format's version" do
      described_class.write(path, feed, [object], now)
      expect(query("PRAGMA user_version", as: Int64)).to eq(Feed::Backend::Executable::Exchange::VERSION)
    end

    it "writes the feed" do
      described_class.write(path, feed, [object], now)
      expect(query("SELECT name, description, params FROM feed", as: {String, String, String})).to eq({"Cats", "Posts about cats", %({"topic":"cats"})})
    end

    it "writes the posts" do
      described_class.write(path, feed, [object], now)
      expect(query(
        "SELECT iri, type, name, summary, content, audience, attachments, published, in_reply_to, thread, quote, language, sensitive, hashtags, mentions, author FROM posts",
        as: {String, String, String, String, String, String, String, String, String, String, String, String, Int64, String, String, String},
      )).to eq({
        object.iri,
        "Object",
        "Cats",
        "<p>About a cat</p>",
        "<p>A cat</p>",
        %(["https://remote/c/cats"]),
        %([{"url":"https://remote/cat.jpg","media_type":"image/jpeg","caption":"A cat"}]),
        "2026-10-22 12:00:00.000",
        "https://remote/objects/parent",
        "https://remote/objects/root",
        "https://remote/objects/quoted",
        "en",
        1_i64,
        %([{"name":"cats","href":"https://remote/tags/cats"}]),
        %([{"name":"alice@remote","href":"https://remote/actors/alice"}]),
        object.attributed_to_iri,
      })
    end

    it "writes the posts' authors" do
      described_class.write(path, feed, [object], now)
      author = Serializers::Author.from(object.attributed_to_iri.not_nil!, feed.owner_iri, now)
      expect(query("SELECT iri, followed, rate_7, rate_30, rate_90 FROM authors", as: {String, Bool, Float64, Float64, Float64})).to eq({author.iri, author.followed, author.rate_7, author.rate_30, author.rate_90})
    end

    it "writes the stats" do
      described_class.write(path, feed, [object], now)
      stats = Serializers::Stats.from(feed.owner_iri, now).posting_rate
      expect(query("SELECT posting_rate_q1, posting_rate_median, posting_rate_q3 FROM stats", as: {Float64?, Float64?, Float64?})).to eq({stats.q1, stats.median, stats.q3})
    end

    context "given another post by the same author" do
      let_build(:object, named: :another, attributed_to: object.attributed_to)

      it "writes each author once" do
        described_class.write(path, feed, [object, another], now)
        expect(query("SELECT count(*) FROM authors", as: Int64)).to eq(1)
      end
    end
  end

  describe ".read" do
    before_each { described_class.write(path, feed, [object]) }

    def answer(sql)
      DB.open("sqlite3://#{path}", &.exec(sql, object.iri))
    end

    context "given an answer that includes the post" do
      before_each { answer("INSERT INTO answers (iri, included, reason) VALUES (?, 1, 'has cats')") }

      it "returns the judgment" do
        expect(described_class.read(path)[object.iri]).to eq(Feed::Backend::Judgment.new(included: true, reason: "has cats"))
      end
    end

    context "given an answer that fails" do
      before_each { answer("INSERT INTO answers (iri, failure, reason) VALUES (?, 'permanent', 'syntax error')") }

      it "returns the failure" do
        expect(described_class.read(path)[object.iri]).to eq(Feed::Backend::Failure.new(:permanent, "syntax error"))
      end
    end

    context "given a judge that subverts the schema's checks to write a malformed answer" do
      before_each do
        DB.open("sqlite3://#{path}") do |db|
          db.using_connection do |connection|
            connection.exec("PRAGMA ignore_check_constraints = ON")
            connection.exec("INSERT INTO answers (iri, failure) VALUES (?, 'sometimes')", object.iri)
          end
        end
      end

      it "returns a transient failure" do
        expect(described_class.read(path)[object.iri].as(Feed::Backend::Failure).kind).to eq(Feed::Backend::Failure::Kind::Transient)
      end
    end
  end
end
