require "../../../../../src/services/feed/backend/executable/exchange"

require "../../../../spec_helper/base"
require "../../../../spec_helper/factory"

Spectator.describe Feed::Backend::Executable::Exchange do
  setup_spec

  let(path) { File.tempname("ktistec", "exchange") }

  after_each { File.delete?(path) }

  let_build(:feed, name: "Cats", description: "Posts about cats", params: JSON.parse(%({"topic":"cats"})).as_h)
  let_build(:object, content: "<p>A cat</p>")

  describe ".write" do
    def query(sql, as types)
      DB.open("sqlite3://#{path}", &.query_one(sql, as: types))
    end

    it "records the format's version" do
      described_class.write(path, feed, [object])
      expect(query("PRAGMA user_version", as: Int64)).to eq(Feed::Backend::Executable::Exchange::VERSION)
    end

    it "writes the feed" do
      described_class.write(path, feed, [object])
      expect(query("SELECT name, description, params FROM feed", as: {String, String, String})).to eq({"Cats", "Posts about cats", %({"topic":"cats"})})
    end

    it "writes the posts" do
      described_class.write(path, feed, [object])
      expect(query("SELECT iri, content FROM posts", as: {String, String})).to eq({object.iri, "<p>A cat</p>"})
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
