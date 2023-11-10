require "../../src/models/activity_pub/object"
require "../../src/views/view_helper"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "object" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  describe "thread.html.slang" do
    let(env) { env_factory("GET", "/objects/123/thread") }

    subject do
      begin
        follow = nil
        XML.parse_html(render "./src/views/objects/thread.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    let(account) { register }

    let_create(:object, in_reply_to_iri: "not dereferenced link")

    let(thread) { [object] }

    it "does not render a button to dereference the link" do
      expect(subject.xpath_nodes("//form[input[@name='iri']]")).to be_empty
    end

    context "if authenticated" do
      before_each { env.account = account }

      it "renders a button to dereference the link" do
        expect(subject.xpath_nodes("//form[input[@name='iri']]")).not_to be_empty
      end

      context "if not a reply" do
        before_each { object.assign(in_reply_to_iri: nil).save }

        it "does not render a button to dereference the link" do
          expect(subject.xpath_nodes("//form[input[@name='iri']]")).to be_empty
        end
      end
    end
  end
end
