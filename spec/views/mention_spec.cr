require "../../src/models/relationship/content/follow/mention"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "index.html.slang" do
  setup_spec

  let(mention) { "actor@remote" }

  let(env) { env_factory("GET", "/mentions/#{mention}") }

  before_each { env.params.url["mention"] = mention }

  let(collection) { Ktistec::Util::PaginatedArray(ActivityPub::Object).new }

  let(follow) { nil }

  let(count) { 0 }

  module Ktistec::ViewHelper
    def self.render_index_html_slang(env, mention, collection, follow, count)
      render "./src/views/mentions/index.html.slang"
    end
  end

  subject do
    begin
      XML.parse_html(Ktistec::ViewHelper.render_index_html_slang(env, mention, collection, follow, count))
    rescue XML::Error
      XML.parse_html("<div/>").document
    end
  end

  let(account) { register }

  it "does not render a button to follow the mention" do
    expect(subject.xpath_nodes("//form//button")).to be_empty
  end

  context "given a follow" do
    let_create!(:follow_mention_relationship, named: follow, actor: account.actor, name: mention)

    it "does not render a button to unfollow the mention" do
      expect(subject.xpath_nodes("//form//button")).to be_empty
    end
  end

  context "if authenticated" do
    sign_in(as: account.username)

    it "renders a button to follow the mention" do
      expect(subject.xpath_nodes("//form//button")).to have("Follow")
    end

    context "given a follow" do
      let_create!(:follow_mention_relationship, named: follow, actor: account.actor, name: mention)

      it "renders a button to unfollow the mention" do
        expect(subject.xpath_nodes("//form//button")).to have("Unfollow")
      end
    end
  end
end
