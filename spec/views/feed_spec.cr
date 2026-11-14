require "../../src/models/feed"
require "../../src/services/feed/backend/criteria"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "feed" do
  setup_spec

  describe "show.html.slang" do
    let(account) { register }

    let_create(:feed, owner: account.actor, name: "Feed", draft: false)

    let(env) { make_env("GET", "/actors/#{account.username}/feeds/#{feed.slug}") }

    let(contents) { Ktistec::Util::PaginatedArray(ActivityPub::Object).new }

    module ::Ktistec::ViewHelper
      def self._view_src_views_feeds_show_html_slang(env, feed, contents)
        render "src/views/feeds/show.html.slang"
      end
    end

    subject do
      begin
        XML.parse_html(Ktistec::ViewHelper._view_src_views_feeds_show_html_slang(env, feed, contents))
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    sign_in(as: account.username)

    it "renders a stream source for the feed" do
      expect(subject.xpath_nodes("//turbo-stream-source/@src").map(&.text)).to eq(["/stream/feeds/#{feed.slug}"])
    end

    context "on a subsequent page" do
      let(env) { make_env("GET", "/actors/#{account.username}/feeds/#{feed.slug}?max-id=1") }

      it "does not render a stream source" do
        expect(subject.xpath_nodes("//turbo-stream-source")).to be_empty
      end
    end

    it "renders a placeholder for the message" do
      expect(subject.xpath_nodes("//*[@id='refresh-posts-message']")).not_to be_empty
    end

    context "given a post in the feed" do
      let_create(:object)

      let(contents) { Ktistec::Util::PaginatedArray(ActivityPub::Object).new.tap { |posts| posts << object } }

      it "still renders a placeholder for the message" do
        expect(subject.xpath_nodes("//*[@id='refresh-posts-message']")).not_to be_empty
      end
    end
  end
end
