require "../../src/models/tag/hashtag"
require "../../src/models/activity_pub/object"
require "../../src/models/relationship/content/follow/hashtag"
require "../../src/models/task/fetch/hashtag"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "index.html.slang" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  let(hashtag) { "hashtag" }

  let(env) { env_factory("GET", "/tags/#{hashtag}") }

  before_each { env.params.url["hashtag"] = hashtag }

  subject do
    begin
      XML.parse_html(render "./src/views/tags/index.html.slang")
    rescue XML::Error
      XML.parse_html("<div/>").document
    end
  end

  let(account) { register }

  let(collection) { Ktistec::Util::PaginatedArray(ActivityPub::Object).new }

  let(follow) { nil }

  let(task) { nil }

  let(count) { 0 }

  it "does not render a button to follow the hashtag" do
    expect(subject.xpath_nodes("//form//button")).to be_empty
  end

  context "given a follow" do
    let_create!(:follow_hashtag_relationship, named: follow, actor: account.actor, name: hashtag)

    it "does not render a button to unfollow the hashtag" do
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
    before_each { env.account = account }

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
