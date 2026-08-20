require "../../../../src/models/activity_pub/activity/quote_request"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Activity::QuoteRequest do
  setup_spec

  subject { described_class.new(iri: "http://test.test/#{random_string}").save }

  describe "#actor" do
    it "returns an actor or actor subclass" do
      expect(typeof(subject.actor)).to eq({{(ActivityPub::Actor.all_subclasses << ActivityPub::Actor).join("|").id}})
    end
  end

  describe "#object" do
    it "returns an object or object subclass" do
      expect(typeof(subject.object)).to eq({{(ActivityPub::Object.all_subclasses << ActivityPub::Object).join("|").id}})
    end
  end

  describe "#instrument" do
    it "returns an object or object subclass" do
      expect(typeof(subject.instrument)).to eq({{(ActivityPub::Object.all_subclasses << ActivityPub::Object).join("|").id}})
    end
  end

  alias Status = ActivityPub::Activity::QuoteRequest::Status

  describe "#status" do
    let_create(:actor, named: :author)
    let_create(:object, named: :quoted, attributed_to: author)
    let_create(:object, named: :quoting)

    let_create!(:quote_request, object: quoted, instrument: quoting)

    subject { described_class.find(quote_request.id) }

    pre_condition { expect(subject.same?(quote_request)).to be_false, "subject must be a reload" }

    it "is awaiting an answer" do
      expect(subject.status).to eq(Status::Awaiting)
    end

    context "given a quoted post that no longer exists" do
      before_each { quoted.destroy }

      it "is invalid" do
        expect(subject.status).to eq(Status::Invalid)
      end
    end

    context "given a quote post that no longer exists" do
      before_each { quoting.destroy }

      it "is invalid" do
        expect(subject.status).to eq(Status::Invalid)
      end
    end

    context "given a reject from the quoted post's author" do
      let_create!(:reject, object: quote_request, actor: author)

      it "is declined" do
        expect(subject.status).to eq(Status::Declined)
      end
    end

    context "given a reject from another actor" do
      let_create(:actor, named: :other)
      let_create!(:reject, object: quote_request, actor: other)

      it "is awaiting an answer" do
        expect(subject.status).to eq(Status::Awaiting)
      end
    end

    context "given an accept from the quoted post's author" do
      let_create!(:accept, object: quote_request, actor: author)

      it "is missing an authorization" do
        expect(subject.status).to eq(Status::AuthorizationMissing)
      end

      context "and the accept names an authorization" do
        let(authorization_iri) { "https://remote/authorizations/#{random_string}" }

        before_each { accept.assign(result_iri: authorization_iri).save }

        it "has an unresolved authorization" do
          expect(subject.status).to eq(Status::AuthorizationUnresolved)
        end

        context "and the authorization has been applied to the quote post" do
          before_each { quoting.assign(quote_authorization_iri: authorization_iri).save }

          it "is authorized" do
            expect(subject.status).to eq(Status::Authorized)
          end

          context "and the quoted post has been deleted" do
            before_each { quoted.delete! }

            it "is authorized" do
              expect(subject.status).to eq(Status::Authorized)
            end
          end

          context "and the quote post has been deleted" do
            before_each { quoting.delete! }

            it "is authorized" do
              expect(subject.status).to eq(Status::Authorized)
            end
          end
        end
      end
    end

    context "given an accept from another actor" do
      let_create(:actor, named: :other)
      let_create!(:accept, object: quote_request, actor: other)

      it "is awaiting an answer" do
        expect(subject.status).to eq(Status::Awaiting)
      end
    end
  end
end

Spectator.describe ActivityPub::Object do
  setup_spec

  let_create(:object, named: :quoted)
  let_create(:object, named: :quoting)

  describe "#quote_request?" do
    it "returns nil" do
      expect(quoting.quote_request?).to be_nil
    end

    context "given a request naming this post as the quote post" do
      let_create!(:quote_request, object: quoted, instrument: quoting)

      it "returns the request" do
        expect(quoting.quote_request?).to eq(quote_request)
      end
    end

    context "given a request naming another post as the quote post" do
      let_create(:object, named: :other)
      let_create!(:quote_request, object: quoted, instrument: other)

      it "returns nil" do
        expect(quoting.quote_request?).to be_nil
      end
    end
  end
end
