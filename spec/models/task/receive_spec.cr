require "../../../src/models/task/receive"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/network"

Spectator.describe Task::Receive do
  setup_spec

  let(receiver) do
    register.actor
  end

  let_build(:activity)

  context "validation" do
    let!(options) do
      {source_iri: receiver.save.iri, subject_iri: activity.save.iri}
    end

    it "rejects missing receiver" do
      new_relationship = described_class.new(**options.merge({source_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("receiver")
    end

    it "rejects missing activity" do
      new_relationship = described_class.new(**options.merge({subject_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("activity")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe "#deliver_to" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity,
      )
    end

    it "retrieves the deliver to value from the state" do
      subject.state = Task::Receive::State.new([] of String)
      expect(subject.deliver_to).to be_a(Array(String))
    end

    it "retrieves the deliver to value from the state" do
      subject.state = Task::Receive::State.new([] of String)
      expect(subject.deliver_to).to be_empty
    end
  end

  describe "#deliver_to=" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity,
      )
    end

    it "stores the deliver to value in the state" do
      subject.deliver_to = ["https://recipient"]
      expect(subject.state.deliver_to).to eq(["https://recipient"])
    end
  end

  describe "#perform" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity,
      )
    end

    context "when the object has already been deleted" do
      let_build(:delete, named: :activity, actor_iri: receiver.iri, object_iri: "https://deleted", to: [receiver.iri])

      it "does not fail" do
        expect { subject.perform }.not_to change { subject.failures }
      end
    end

    context "when the activity object is local" do
      let(authorization_iri) { "https://remote/authorizations/#{random_string}" }

      let_create(:object, named: :quote, local: false)
      let_create(:object, named: :post, local: true, quote_iri: quote.iri, quote_authorization_iri: authorization_iri)
      let_build(:create, named: :activity, actor_iri: receiver.iri, object_iri: post.iri, to: [receiver.iri])

      before_each do
        HTTP::Client.objects << quote
        HTTP::Client.actors << quote.attributed_to
      end

      it "does not dereference the quote authorization" do
        subject.perform
        expect(HTTP::Client.requests).not_to have("GET #{authorization_iri}")
      end
    end

    context "when the activity object has a quote" do
      let_build(:object, named: :quote)
      let_create(:object, named: :post, quote_iri: quote.iri)
      let_build(:create, named: :activity, actor_iri: receiver.iri, object_iri: post.iri, to: [receiver.iri])

      before_each do
        HTTP::Client.objects << quote
        HTTP::Client.actors << quote.attributed_to
      end

      it "dereferences the quote" do
        expect { subject.perform }.to change { ActivityPub::Object.find?(iri: quote.iri) }
      end

      it "dereferences the quote's author" do
        expect { subject.perform }.to change { ActivityPub::Actor.find?(iri: quote.attributed_to.iri) }
      end

      context "and the quoted object cannot be fetched" do
        before_each do
          post.assign(quote_iri: "https://remote/objects/missing").save
        end

        it "requests the quoted object" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET https://remote/objects/missing")
        end

        it "does not dereference the quoted object" do
          expect { subject.perform }.not_to change { ActivityPub::Object.find?(iri: "https://remote/objects/missing") }
        end

        it "does not fail" do
          expect { subject.perform }.not_to change { subject.failures }
        end
      end

      context "with a quote_authorization_iri" do
        let(authorization_iri) { "https://remote/authorizations/#{random_string}" }

        before_each do
          post.assign(quote_authorization_iri: authorization_iri).save
        end

        context "and the quote is a self-quote" do
          before_each do
            post.assign(attributed_to_iri: quote.attributed_to_iri).save
          end

          it "does not dereference the quote authorization" do
            subject.perform
            expect(HTTP::Client.requests).not_to have("GET #{authorization_iri}")
          end
        end

        context "and the quote is not a self-quote" do
          let_build(:quote_decision, interacting_object: post, interaction_target: quote)
          let_build(:quote_authorization, quote_decision: quote_decision, attributed_to: quote.attributed_to, iri: authorization_iri)

          before_each do
            HTTP::Client.objects << quote_authorization
          end

          it "dereferences the quote authorization" do
            subject.perform
            expect(HTTP::Client.requests).to have("GET #{authorization_iri}")
          end

          it "saves the quote authorization" do
            expect { subject.perform }.to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
          end

          context "and quote authorization has wrong interacting_object_iri" do
            before_each do
              quote_decision.interacting_object_iri = "https://remote/wrong"
              HTTP::Client.objects << quote_authorization
            end

            it "does not save the quote authorization" do
              expect { subject.perform }.not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end
          end

          context "and quote authorization has wrong interaction_target_iri" do
            before_each do
              quote_decision.interaction_target_iri = "https://remote/wrong"
              HTTP::Client.objects << quote_authorization
            end

            it "does not save the quote authorization" do
              expect { subject.perform }.not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end
          end

          context "and quote authorization has wrong attributed_to_iri" do
            before_each do
              quote_authorization.attributed_to_iri = "https://remote/wrong"
              HTTP::Client.objects << quote_authorization
            end

            it "does not save the quote authorization" do
              expect { subject.perform }.not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end
          end

          context "when quote authorization cannot be dereferenced" do
            before_each do
              HTTP::Client.cache.delete(authorization_iri)
            end

            it "does not save the quote authorization" do
              expect { subject.perform }.not_to change { ActivityPub::Object::QuoteAuthorization.find?(iri: authorization_iri) }
            end

            it "does not fail" do
              expect { subject.perform }.not_to change { subject.failures }
            end
          end
        end
      end
    end
  end
end
