require "../../src/models/relationship/content/follow/hashtag"
require "../../src/models/task/fetch/hashtag"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "index.html.slang" do
  setup_spec

  let(hashtag) { "hashtag" }

  let(env) { env_factory("GET", "/tags/#{hashtag}") }

  before_each { env.params.url["hashtag"] = hashtag }

  let(collection) { Ktistec::Util::PaginatedArray(ActivityPub::Object).new }

  let(follow) { nil }

  let(task) { nil }

  let(count) { 0 }

  module Ktistec::ViewHelper
    def self.render_index_html_slang(env, hashtag, collection, follow, task, count)
      render "./src/views/tags/index.html.slang"
    end
  end

  subject do
    begin
      XML.parse_html(Ktistec::ViewHelper.render_index_html_slang(env, hashtag, collection, follow, task, count))
    rescue XML::Error
      XML.parse_html("<div/>").document
    end
  end

  let(account) { register }

  it "does not render turbo-stream-source tag" do
    expect(subject.xpath_nodes("//turbo-stream-source")).to be_empty
  end

  it "does not render any controls" do
    expect(subject.xpath_nodes("//form//button")).to be_empty
  end

  context "given a follow" do
    let_create!(:follow_hashtag_relationship, named: follow, actor: account.actor, name: hashtag)

    it "does not render any controls" do
      expect(subject.xpath_nodes("//form//button")).to be_empty
    end
  end

  it "does not render information about the task" do
    expect(subject.xpath_nodes("//p[@class='task']")).to be_empty
  end

  context "given a task" do
    let_create!(:fetch_hashtag_task, named: task, source: account.actor, name: hashtag)

    it "does not render information about the task" do
      expect(subject.xpath_nodes("//p[@class='task']")).to be_empty
    end
  end

  context "if authenticated" do
    sign_in(as: account.username)

    it "renders turbo-stream-source tag" do
      expect(subject.xpath_nodes("//turbo-stream-source")).not_to be_empty
    end

    it "renders a button to follow the hashtag" do
      expect(subject.xpath_nodes("//form//button")).to have("Follow")
    end

    context "given a follow" do
      let_create!(:follow_hashtag_relationship, named: follow, actor: account.actor, name: hashtag)

      it "renders a button to unfollow the hashtag" do
        expect(subject.xpath_nodes("//form//button")).to have("Unfollow")
      end
    end

    it "does not render information about the task" do
      expect(subject.xpath_nodes("//p[@class='task']")).to be_empty
    end

    context "given a task" do
      let_create!(:fetch_hashtag_task, named: task, source: account.actor, name: hashtag)

      it "renders information about the task" do
        expect(subject.xpath_nodes("//p[@class='task']")).not_to be_empty
      end
    end
  end
end
