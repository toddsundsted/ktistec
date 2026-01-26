require "../../src/models/activity_pub/object"
require "../../src/models/task/fetch/thread"
require "../../src/views/view_helper"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "thread.html.slang" do
  setup_spec

  let(env) { make_env("GET", "/objects/123/thread") }

  let_create(:object)

  let(thread) { [object] }

  let(follow) { nil }

  let(task) { nil }

  module ::Ktistec::ViewHelper
    def self.render_thread_html_slang(env, object, thread, follow, task)
      render "./src/views/objects/thread.html.slang"
    end
  end

  subject do
    begin
      XML.parse_html(Ktistec::ViewHelper.render_thread_html_slang(env, object, thread, follow, task))
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
    let_create!(:follow_thread_relationship, named: follow, actor: account.actor, name: "https://remote/thread")

    it "does not render any controls" do
      expect(subject.xpath_nodes("//form//button")).to be_empty
    end
  end

  it "does not render information about the task" do
    expect(subject.xpath_nodes("//p[@class='task']")).to be_empty
  end

  context "given a task" do
    let_create!(:fetch_thread_task, named: task, source: account.actor, name: "https://remote/thread")

    it "does not render information about the task" do
      expect(subject.xpath_nodes("//p[@class='task']")).to be_empty
    end
  end

  context "if authenticated" do
    sign_in(as: account.username)

    it "renders turbo-stream-source tag" do
      expect(subject.xpath_nodes("//turbo-stream-source")).not_to be_empty
    end

    it "renders a button to follow the thread" do
      expect(subject.xpath_nodes("//form//button")).to have("Follow")
    end

    context "given a follow" do
      let_create!(:follow_thread_relationship, named: follow, actor: account.actor, name: "https://remote/thread")

      it "renders a button to unfollow the thread" do
        expect(subject.xpath_nodes("//form//button")).to have("Unfollow")
      end
    end

    it "does not render information about the task" do
      expect(subject.xpath_nodes("//p[@class='task']")).to be_empty
    end

    context "given a task" do
      let_create!(:fetch_thread_task, named: task, source: account.actor, name: "https://remote/thread")

      it "renders information about the task" do
        expect(subject.xpath_nodes("//p[@class='task']")).not_to be_empty
      end
    end
  end
end
