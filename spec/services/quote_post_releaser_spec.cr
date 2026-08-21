require "../../src/services/quote_post_releaser"

require "../spec_helper/base"
require "../spec_helper/factory"
require "../spec_helper/network"

Spectator.describe QuotePostReleaser do
  setup_spec

  let(actor) { register.actor }
  let_create(:actor, named: :other)

  let(authorization_iri) { "https://remote/authorizations/#{random_string}" }

  let_create(:note, named: :quoted_post, attributed_to: other)
  let_create(:note, named: :quote_post, published: nil, attributed_to: actor, local: true, quote: quoted_post)
  let_create(:quote_request, actor: actor, object: quoted_post, instrument: quote_post)

  let(state) do
    Task::DeliverDelayedObject::State.new(
      Task::DeliverDelayedObject::State::Reason::PendingQuoteAuthorization,
      Task::DeliverDelayedObject::State::PendingQuoteAuthorizationContext.new(quote_request.iri),
    )
  end

  let_create!(:deliver_delayed_object_task, actor: actor, object: quote_post, state: state)

  subject { described_class.release(actor, quote_request, authorization_iri) }

  pre_condition { expect(quote_post.draft?).to be_true }

  context "given an authorization that cannot be fetched" do
    it "does not release the post" do
      expect { subject }.not_to change { quote_post.reload!.published }
    end

    it "returns false" do
      expect(subject).to be_false
    end
  end

  context "given an authorization that does not match the quote post" do
    let_build(:quote_decision, interacting_object_iri: "https://remote/wrong", interaction_target: quoted_post)
    let_build(:quote_authorization, quote_decision: quote_decision, attributed_to: other, iri: authorization_iri)

    before_each { HTTP::Client.objects << quote_authorization }

    it "does not release the post" do
      expect { subject }.not_to change { quote_post.reload!.published }
    end

    it "returns false" do
      expect(subject).to be_false
    end
  end

  context "given an authorization from the quoted post's author" do
    let_build(:quote_decision, interacting_object: quote_post, interaction_target: quoted_post)
    let_build(:quote_authorization, quote_decision: quote_decision, attributed_to: other, iri: authorization_iri)

    before_each { HTTP::Client.objects << quote_authorization }

    it "releases the post" do
      expect { subject }.to change { quote_post.reload!.published }
    end

    it "applies the authorization" do
      expect { subject }.to change { quote_post.reload!.quote_authorization_iri }.to(authorization_iri)
    end

    it "returns true" do
      expect(subject).to be_true
    end
  end
end
