require "../../src/views/view_helper"
require "../../src/models/activity_pub/object"
require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "views/partials/object/content/quote.html.slang" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  subject do
    begin
      XML.parse_html(Ktistec::ViewHelper._view_src_views_partials_object_content_quote_html_slang(env, object, quote, failed))
    rescue XML::Error
      XML.parse_html("<div/>").document
    end
  end

  let(account) { register }
  let(actor) { account.actor }

  let_create(:object, attributed_to: actor, published: Time.utc)

  let(quote) { nil }
  let(failed) { false }

  let(env) { make_env("GET", "/objects") }

  context "when not cached" do
    before_each { object.assign(quote_iri: "https://remote/objects/123").save }

    it "renders reload button" do
      expect(subject.xpath_nodes("//button[contains(text(),'Load quoted post')]")).not_to be_empty
    end

    it "renders turbo-frame target" do
      expect(subject.xpath_nodes("//form[@data-turbo-frame='quote-#{object.id}']")).not_to be_empty
    end

    it "does not render quoted post" do
      expect(subject.xpath_nodes("//section[@class='ui feed']//div[@class='content']")).to be_empty
    end
  end

  context "when cached" do
    let_create(:object, named: :quote, attributed_to: actor, published: Time.utc, content: "This is a quoted post.")

    before_each { object.assign(quote: quote).save }

    before_each { actor.assign(icon: "https://test.test/image.jpg").save }

    it "renders quoted post" do
      expect(subject.xpath_nodes("//section[@class='ui feed']//div[@class='content']")).not_to be_empty
    end

    it "renders quoted author's icon" do
      expect(subject.xpath_nodes("//img[contains(@class,'avatar image')]/@src")).to have(actor.icon)
    end

    it "renders quoted author's display name" do
      expect(subject.xpath_nodes("//a[@class='user']")).to have(actor.display_name)
    end

    it "renders quoted post date" do
      expect(subject.xpath_nodes("//a[@class='date']")).to have(object.short_date)
    end

    it "renders quoted post content" do
      expect(subject.xpath_nodes("//div[@class='extra text']")).to have("This is a quoted post.")
    end

    it "does not render reload button" do
      expect(subject.xpath_nodes("//button[contains(text(),'Load quoted post')]")).to be_empty
    end

    context "with attachments" do
      let(attachments) { [ActivityPub::Object::Attachment.new("https://remote/image.jpg", "image/jpeg")] }

      before_each { quote.assign(attachments: attachments).save }

      it "renders attachments" do
        expect(subject.xpath_nodes("//img[contains(@class,'attachment image')]/@src")).to have("https://remote/image.jpg")
      end
    end

    context "when quoted object has a quote" do
      let_create(:object, named: :other, published: Time.utc)

      before_each { quote.assign(quote: other).save }

      it "does not render nested quote card" do
        expect(subject.xpath_nodes("//section[@class='ui feed']//div[@class='content']").size).to eq(1)
      end
    end

    context "but object is deleted" do
      before_each { quote.delete! }

      it "renders 'This post is deleted!' message" do
        expect(subject.xpath_nodes("//em[text()='This post is deleted!']")).not_to be_empty
      end

      it "does not render quoted content" do
        expect(subject.xpath_nodes("//section[@class='ui feed']//div[@class='content']")).to be_empty
      end

      it "does not render a reload button" do
        expect(subject.xpath_nodes("//button[contains(text(),'Load quoted post')]")).to be_empty
      end
    end

    context "but object is blocked" do
      before_each { quote.block! }

      it "renders 'This post is blocked!' message" do
        expect(subject.xpath_nodes("//em[text()='This post is blocked!']")).not_to be_empty
      end

      it "does not render quoted content" do
        expect(subject.xpath_nodes("//section[@class='ui feed']//div[@class='content']")).to be_empty
      end

      it "does not render a reload button" do
        expect(subject.xpath_nodes("//button[contains(text(),'Load quoted post')]")).to be_empty
      end
    end
  end

  context "dereference failed" do
    let(failed) { true }

    it "renders 'Failed' message" do
      expect(subject.xpath_nodes("//em[text()='Failed to load!']")).not_to be_empty
    end

    it "does not render quoted content" do
      expect(subject.xpath_nodes("//section[@class='ui feed']//div[@class='content']")).to be_empty
    end

    it "does not render a reload button" do
      expect(subject.xpath_nodes("//button[contains(text(),'Load quoted post')]")).to be_empty
    end
  end
end
