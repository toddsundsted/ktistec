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
      XML.parse_html(Ktistec::ViewHelper._view_src_views_partials_object_content_quote_html_slang(env, object, quote, failed, error_message))
    rescue XML::Error
      XML.parse_html("<div/>").document
    end
  end

  let(account) { register }
  let(actor) { account.actor }

  let_create(:object, attributed_to: actor, published: Time.utc)

  let(quote) { nil }
  let(failed) { false }
  let(error_message) { nil }

  let(env) { make_env("GET", "/objects") }

  MESSAGE_TEXT_PATH = "//*[contains(@class,'quoted-object')][not(section)]//em/text()"
  BUTTON_TEXT_XPATH = "//*[contains(@class,'quoted-object')][not(section)]//button/text()"
  CONTENT_XPATH     = "//section[@class='ui feed']//div[@class='content']"

  context "when not cached" do
    before_each { object.assign(quote_iri: "https://remote/objects/123").save }

    it "renders reload button" do
      expect(subject.xpath_nodes(BUTTON_TEXT_XPATH)).to contain_exactly("Load quoted post")
    end

    it "renders turbo-frame target" do
      expect(subject.xpath_nodes("//form[@data-turbo-frame='quote-#{object.id}']")).not_to be_empty
    end

    it "does not render quoted post" do
      expect(subject.xpath_nodes(CONTENT_XPATH)).to be_empty
    end
  end

  context "when cached" do
    let_create(:object, named: :quote, attributed_to: actor, published: Time.utc, content: "This is a quoted post.")

    before_each { object.assign(quote: quote).save }

    before_each { actor.assign(icon: "https://test.test/image.jpg").save }

    it "renders quoted post" do
      expect(subject.xpath_nodes(CONTENT_XPATH)).not_to be_empty
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

    it "does not render buttons" do
      expect(subject.xpath_nodes(BUTTON_TEXT_XPATH)).to be_empty
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
        expect(subject.xpath_nodes(CONTENT_XPATH).size).to eq(1)
      end
    end

    context "but object is deleted" do
      before_each { quote.delete! }

      it "renders 'This post is deleted!' message" do
        expect(subject.xpath_nodes(MESSAGE_TEXT_PATH)).to contain_exactly("This post is deleted!")
      end

      it "does not render quoted content" do
        expect(subject.xpath_nodes(CONTENT_XPATH)).to be_empty
      end

      it "does not render buttons" do
        expect(subject.xpath_nodes(BUTTON_TEXT_XPATH)).to be_empty
      end
    end

    context "but object is blocked" do
      before_each { quote.block! }

      it "renders 'This post is blocked!' message" do
        expect(subject.xpath_nodes(MESSAGE_TEXT_PATH)).to contain_exactly("This post is blocked!")
      end

      it "does not render quoted content" do
        expect(subject.xpath_nodes(CONTENT_XPATH)).to be_empty
      end

      it "does not render buttons" do
        expect(subject.xpath_nodes(BUTTON_TEXT_XPATH)).to be_empty
      end
    end

    context "when the quote is not a self-quote" do
      let_create(:actor, named: :other)

      before_each { quote.assign(attributed_to: other).save }

      it "renders 'This quote cannot be verified.' message" do
        expect(subject.xpath_nodes(MESSAGE_TEXT_PATH)).to contain_exactly("This quote cannot be verified.")
      end

      it "does not render the quoted content" do
        expect(subject.xpath_nodes(CONTENT_XPATH)).to be_empty
      end

      it "does not render buttons" do
        expect(subject.xpath_nodes(BUTTON_TEXT_XPATH)).to be_empty
      end

      context "and quote_authorization_iri exists but authorization not cached" do
        before_each { object.assign(quote_authorization_iri: "https://remote/authorizations/123").save }

        it "renders 'This quote has not been verified.' message" do
          expect(subject.xpath_nodes(MESSAGE_TEXT_PATH)).to contain_exactly("This quote has not been verified.")
        end

        it "does not render the quoted content" do
          expect(subject.xpath_nodes(CONTENT_XPATH)).to be_empty
        end

        it "renders a verify button" do
          expect(subject.xpath_nodes(BUTTON_TEXT_XPATH)).to contain_exactly("Verify quote")
        end
      end

      context "and the quote authorization is cached" do
        let_create(:quote_authorization, attributed_to: other)

        before_each { object.assign(quote_authorization_iri: quote_authorization.iri).save }

        it "does not render message" do
          expect(subject.xpath_nodes(MESSAGE_TEXT_PATH)).to be_empty
        end

        it "renders quoted post" do
          expect(subject.xpath_nodes(CONTENT_XPATH)).not_to be_empty
        end

        it "does not render buttons" do
          expect(subject.xpath_nodes(BUTTON_TEXT_XPATH)).to be_empty
        end
      end

      context "and error_message is set" do
        let(error_message) { "Authorization does not match this quote." }

        it "renders the error message" do
          expect(subject.xpath_nodes(MESSAGE_TEXT_PATH)).to contain_exactly("Authorization does not match this quote.")
        end

        it "does not render the quoted content" do
          expect(subject.xpath_nodes(CONTENT_XPATH)).to be_empty
        end

        it "does not render buttons" do
          expect(subject.xpath_nodes(BUTTON_TEXT_XPATH)).to be_empty
        end
      end
    end
  end

  context "dereference failed" do
    let(failed) { true }

    it "renders 'Failed to load!' message" do
      expect(subject.xpath_nodes(MESSAGE_TEXT_PATH)).to contain_exactly("Failed to load!")
    end

    it "does not render quoted content" do
      expect(subject.xpath_nodes(CONTENT_XPATH)).to be_empty
    end

    it "does not render buttons" do
      expect(subject.xpath_nodes(BUTTON_TEXT_XPATH)).to be_empty
    end
  end
end
