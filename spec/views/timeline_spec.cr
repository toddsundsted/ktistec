require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "timeline partial" do
  setup_spec

  include Ktistec::Controller

  module Ktistec::ViewHelper
    def self.render_timeline_html_slang(env, actor, timeline)
      render "./src/views/actors/timeline.html.slang"
    end

    def self.render_timeline_json_ecr(env, actor, timeline)
      render "./src/views/actors/timeline.json.ecr"
    end
  end

  describe "timeline.html.slang" do
    let(env) { env_factory("GET", "/timeline") }

    subject do
      begin
        XML.parse_html(Ktistec::ViewHelper.render_timeline_html_slang(env, actor, timeline))
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    let(account) { register }
    let(actor) { account.actor }

    let(timeline) { actor.timeline }

    it "renders an empty page" do
      expect(subject.xpath_nodes("//section/*[contains(@class,'event')]")).to be_empty
    end

    it "renders a stream source" do
      expect(subject.xpath_nodes("//turbo-stream-source")).not_to be_empty
    end

    context "given a query string" do
      let(env) { env_factory("GET", "/timeline?foo=bar") }

      it "renders a stream source with the query string" do
        expect(subject.xpath_nodes("//turbo-stream-source/@src").first).to eq("/stream/actor/homepage?foo=bar")
      end
    end
  end

  describe "timeline.json.ecr" do
    let(env) { env_factory("GET", "/timeline") }

    subject do
      begin
        JSON.parse(Ktistec::ViewHelper.render_timeline_json_ecr(env, actor, timeline))
      rescue JSON::ParseException
        JSON.parse("{}")
      end
    end

    let(account) { register }
    let(actor) { account.actor }

    let(timeline) { actor.timeline }

    it "renders an empty collection" do
      expect(subject["first"]["orderedItems"].as_a).to be_empty
    end
  end
end
