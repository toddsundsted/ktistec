{% if flag?(:with_mastodon_api) %}
  require "../../../src/api/serializers/status"

  require "../../spec_helper/base"
  require "../../spec_helper/factory"

  Spectator.describe API::V1::Serializers::Status do
    setup_spec

    describe ".from_object" do
      let(published) { Time.utc(2024, 6, 15, 12, 0, 0) }
      let_create(:actor, username: "testuser", published: published, local: true)
      let_create(:object, attributed_to: actor, published: published, visible: true)

      subject { described_class.from_object(object) }

      it "returns id" do
        expect(subject.id).to eq(object.id.to_s)
      end

      it "returns uri" do
        expect(subject.uri).to eq(object.iri)
      end

      it "returns created_at" do
        expect(subject.created_at).to eq(published.to_rfc3339)
      end

      it "returns account" do
        expect(subject.account.id).to eq(actor.id.to_s)
      end

      it "returns content" do
        expect(subject.content).to eq("")
      end

      it "returns visibility" do
        expect(subject.visibility).to eq("public")
      end

      it "returns sensitive" do
        expect(subject.sensitive).to be_false
      end

      it "returns spoiler_text" do
        expect(subject.spoiler_text).to eq("")
      end

      it "returns media_attachments" do
        expect(subject.media_attachments).to be_empty
      end

      it "returns mentions" do
        expect(subject.mentions).to be_empty
      end

      it "returns tags" do
        expect(subject.tags).to be_empty
      end

      it "returns emojis" do
        expect(subject.emojis).to be_empty
      end

      it "returns reblogs_count" do
        expect(subject.reblogs_count).to eq(0)
      end

      it "returns favourites_count" do
        expect(subject.favourites_count).to eq(0)
      end

      it "returns quotes_count" do
        expect(subject.quotes_count).to eq(0)
      end

      it "returns replies_count" do
        expect(subject.replies_count).to eq(0)
      end

      it "returns url" do
        expect(subject.url).to be_nil
      end

      it "returns in_reply_to_id" do
        expect(subject.in_reply_to_id).to be_nil
      end

      it "returns in_reply_to_account_id" do
        expect(subject.in_reply_to_account_id).to be_nil
      end

      it "returns reblog" do
        expect(subject.reblog).to be_nil
      end

      it "returns poll" do
        expect(subject.poll).to be_nil
      end

      it "returns card" do
        expect(subject.card).to be_nil
      end

      it "returns language" do
        expect(subject.language).to be_nil
      end

      it "returns text" do
        expect(subject.text).to be_nil
      end

      it "returns edited_at" do
        expect(subject.edited_at).to be_nil
      end

      it "returns quote" do
        expect(subject.quote).to be_nil
      end

      it "returns quote_approval.automatic" do
        expect(subject.quote_approval.automatic).to eq(["public"])
      end

      it "returns quote_approval.manual" do
        expect(subject.quote_approval.manual).to be_empty
      end

      it "returns quote_approval.current_user" do
        expect(subject.quote_approval.current_user).to eq("unknown")
      end

      it "returns favourited" do
        expect(subject.favourited).to be_false
      end

      it "returns reblogged" do
        expect(subject.reblogged).to be_false
      end

      it "returns muted" do
        expect(subject.muted).to be_false
      end

      it "returns bookmarked" do
        expect(subject.bookmarked).to be_false
      end

      it "returns pinned" do
        expect(subject.pinned).to be_false
      end

      it "returns filtered" do
        expect(subject.filtered).to be_empty
      end

      context "with content" do
        before_each { object.assign(content: "<p>Hello world</p>").save }

        it "returns content" do
          expect(subject.content).to eq("<p>Hello world</p>")
        end
      end

      PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

      context "visibility" do
        context "when public" do
          before_each { object.assign(to: [PUBLIC]).save }

          it "returns public" do
            expect(subject.visibility).to eq("public")
          end
        end

        context "when private" do
          before_each { object.assign(to: ["#{actor.iri}/followers"]).save }

          it "returns private" do
            expect(subject.visibility).to eq("private")
          end
        end

        context "when direct" do
          before_each { object.assign(to: ["https://example.com/someone"]).save }

          it "returns direct" do
            expect(subject.visibility).to eq("direct")
          end
        end
      end

      context "with sensitive" do
        before_each { object.assign(sensitive: true).save }

        it "returns sensitive" do
          expect(subject.sensitive).to be_true
        end
      end

      context "with summary" do
        before_each { object.assign(summary: "Content warning").save }

        it "returns spoiler_text" do
          expect(subject.spoiler_text).to eq("Content warning")
        end
      end

      context "with attachments" do
        before_each do
          object.assign(
            attachments: [
              ActivityPub::Object::Attachment.new(
                url: "https://example.com/image.png",
                media_type: "image/png",
                caption: "An image",
                focal_point: {0.5, -0.25},
              ),
            ]
          ).save
        end

        it "returns media_attachments" do
          expect(subject.media_attachments.size).to eq(1)
        end

        it "returns attachment id" do
          expect(subject.media_attachments.first.id).to eq("#{object.id}_0")
        end

        it "returns attachment type" do
          expect(subject.media_attachments.first.type).to eq("image")
        end

        it "returns attachment url" do
          expect(subject.media_attachments.first.url).to eq("https://example.com/image.png")
        end

        it "returns attachment preview_url" do
          expect(subject.media_attachments.first.preview_url).to eq("https://example.com/image.png")
        end

        it "returns attachment description" do
          expect(subject.media_attachments.first.description).to eq("An image")
        end

        it "returns meta" do
          expect(subject.media_attachments.first.meta).not_to be_nil
        end

        it "returns focus x" do
          expect(subject.media_attachments.first.meta.not_nil!.focus.not_nil!.x).to eq(0.5)
        end

        it "returns focus y" do
          expect(subject.media_attachments.first.meta.not_nil!.focus.not_nil!.y).to eq(-0.25)
        end
      end

      context "with urls" do
        before_each { object.assign(urls: ["https://example.com/status/1"]).save }

        it "returns url" do
          expect(subject.url).to eq("https://example.com/status/1")
        end
      end

      context "with in_reply_to" do
        let_create(:actor, named: :other, local: true)
        let_create(:object, named: :parent, attributed_to: other, published: published)

        before_each { object.assign(in_reply_to: parent).save }

        it "returns in_reply_to_id" do
          expect(subject.in_reply_to_id).to eq(parent.id.to_s)
        end

        it "returns in_reply_to_account_id" do
          expect(subject.in_reply_to_account_id).to eq(other.id.to_s)
        end
      end

      context "with poll" do
        let(poll_options) { [Poll::Option.new("Yes", 5), Poll::Option.new("No", 3)] }
        let(closed_at) { Time.utc(2024, 6, 20, 12, 0, 0) }
        let_create(:poll, options: poll_options, closed_at: closed_at, multiple_choice: false)
        let_create(:question, poll: poll, published: published)

        subject { described_class.from_object(question) }

        let(api_poll) { subject.poll.not_nil! }

        it "returns poll id" do
          expect(api_poll.id).to eq(poll.id.to_s)
        end

        it "returns poll expires_at" do
          expect(api_poll.expires_at).to eq(closed_at.not_nil!.to_rfc3339)
        end

        it "returns poll expired" do
          expect(api_poll.expired).to be_true
        end

        it "returns poll multiple" do
          expect(api_poll.multiple).to be_false
        end

        it "returns poll votes_count" do
          expect(api_poll.votes_count).to eq(8)
        end

        it "returns poll voters_count" do
          expect(api_poll.voters_count).to be_nil
        end

        it "returns poll options" do
          expect(api_poll.options.size).to eq(2)
        end

        it "returns poll option title" do
          expect(api_poll.options.first.title).to eq("Yes")
        end

        it "returns poll option votes_count" do
          expect(api_poll.options.first.votes_count).to eq(5)
        end

        it "returns poll voted" do
          expect(api_poll.voted).to be_false
        end

        it "returns poll own_votes" do
          expect(api_poll.own_votes).to be_empty
        end

        it "returns poll emojis" do
          expect(api_poll.emojis).to be_empty
        end

        context "with multiple choice" do
          before_each { poll.assign(multiple_choice: true, voters_count: 6) }

          it "returns poll multiple" do
            expect(api_poll.multiple).to be_true
          end

          it "returns voters_count" do
            expect(api_poll.voters_count).to eq(6)
          end
        end

        context "when not expired" do
          let(closed_at) { Time.utc + 1.day }

          it "returns expired" do
            expect(api_poll.expired).to be_false
          end
        end

        context "with no expiry" do
          let(closed_at) { nil }

          it "returns expires_at" do
            expect(api_poll.expires_at).to be_nil
          end

          it "returns expired" do
            expect(api_poll.expired).to be_false
          end
        end
      end

      context "with quote" do
        let_create(:actor, named: :other, local: true)
        let_create(:object, named: :quoted, attributed_to: other, published: published, visible: true)
        let_create(:object, named: :quoting, attributed_to: actor, quote_iri: quoted.iri, published: published, visible: true)

        subject { described_class.from_object(quoting) }

        let(api_quote) { subject.quote.not_nil! }

        it "returns quote state" do
          expect(api_quote.state).to eq("pending")
        end

        it "returns quote quoted_status" do
          expect(api_quote.quoted_status).to be_nil
        end

        context "with accepted authorization" do
          let_create!(:quote_authorization, attributed_to: other)
          let_create!(:quote_decision,
            quote_authorization: quote_authorization,
            interacting_object: quoting,
            interaction_target: quoted,
            decision: "accept"
          )

          before_each { quoting.assign(quote_authorization: quote_authorization).save }

          it "returns quote state" do
            expect(api_quote.state).to eq("accepted")
          end

          it "returns quote quoted_status" do
            expect(api_quote.quoted_status).not_to be_nil
          end

          let(:quoted_status) { api_quote.quoted_status.not_nil! }

          it "returns quoted_status id" do
            expect(quoted_status.id).to eq(quoted.id.to_s)
          end

          it "returns quoted_status account" do
            expect(quoted_status.account.id).to eq(other.id.to_s)
          end
        end

        context "with rejected authorization" do
          let_create!(:quote_authorization, attributed_to: other)
          let_create!(:quote_decision,
            quote_authorization: quote_authorization,
            interacting_object: quoting,
            interaction_target: quoted,
            decision: "reject"
          )

          before_each { quoting.assign(quote_authorization: quote_authorization).save }

          it "returns quote state" do
            expect(api_quote.state).to eq("rejected")
          end

          it "returns nil quoted_status" do
            expect(api_quote.quoted_status).to be_nil
          end
        end

        context "when self-quote" do
          let_create(:object, named: :quoted, attributed_to: actor, published: published, visible: true)
          let_create(:object, named: :quoting, attributed_to: actor, quote_iri: quoted.iri, published: published, visible: true)

          subject { described_class.from_object(quoting) }

          let(api_quote) { subject.quote.not_nil! }

          it "returns quote state" do
            expect(api_quote.state).to eq("accepted")
          end

          it "returns quote quoted_status" do
            expect(api_quote.quoted_status).not_to be_nil
          end

          let(:quoted_status) { api_quote.quoted_status.not_nil! }

          it "returns quoted_status id" do
            expect(quoted_status.id).to eq(quoted.id.to_s)
          end
        end

        context "when quoted object is deleted" do
          before_each { quoting.assign(quote_iri: "https://deleted.example/object/123").save }

          it "returns quote state" do
            expect(api_quote.state).to eq("deleted")
          end

          it "returns quote quoted_status" do
            expect(api_quote.quoted_status).to be_nil
          end
        end
      end

      context "with language" do
        before_each { object.assign(language: "fr").save }

        it "returns language" do
          expect(subject.language).to eq("fr")
        end
      end

      context "with updated" do
        let(updated) { Time.utc(2024, 6, 16, 14, 30, 0) }

        before_each { object.assign(updated: updated).save }

        it "returns edited_at" do
          expect(subject.edited_at).to eq(updated.to_rfc3339)
        end
      end
    end

    describe "#to_json" do
      let(published) { Time.utc(2024, 6, 15, 12, 0, 0) }
      let_create(:object, published: published, visible: true, content: "<p>Test</p>")

      subject { described_class.from_object(object) }

      it "produces valid JSON with all required fields" do
        json = JSON.parse(subject.to_json)
        expect(json["id"]).to eq(object.id.to_s)
        expect(json["uri"]).to eq(object.iri)
        expect(json["created_at"]).to eq(published.to_rfc3339)
        expect(json["account"]["id"]).to eq(object.attributed_to.id.to_s)
        expect(json["content"]).to eq("<p>Test</p>")
        expect(json["visibility"]).to eq("public")
        expect(json["sensitive"]).to be_false
        expect(json["spoiler_text"]).to eq("")
        expect(json["media_attachments"].as_a).to be_empty
        expect(json["mentions"].as_a).to be_empty
        expect(json["tags"].as_a).to be_empty
        expect(json["emojis"].as_a).to be_empty
        expect(json["reblogs_count"]).to eq(0)
        expect(json["favourites_count"]).to eq(0)
        expect(json["quotes_count"]).to eq(0)
        expect(json["replies_count"]).to eq(0)
        expect(json["url"].as_nil).to be_nil
        expect(json["in_reply_to_id"].as_nil).to be_nil
        expect(json["in_reply_to_account_id"].as_nil).to be_nil
        expect(json["reblog"].as_nil).to be_nil
        expect(json["poll"].as_nil).to be_nil
        expect(json["card"].as_nil).to be_nil
        expect(json["language"].as_nil).to be_nil
        expect(json["text"].as_nil).to be_nil
        expect(json["edited_at"].as_nil).to be_nil
        expect(json["quote"].as_nil).to be_nil
        expect(json["quote_approval"]["automatic"].as_a).to eq(["public"])
        expect(json["quote_approval"]["manual"].as_a).to be_empty
        expect(json["quote_approval"]["current_user"]).to eq("unknown")
        expect(json["favourited"]).to be_false
        expect(json["reblogged"]).to be_false
        expect(json["muted"]).to be_false
        expect(json["bookmarked"]).to be_false
        expect(json["pinned"]).to be_false
        expect(json["filtered"]).to be_empty
      end
    end
  end
{% end %}
