require "../../../src/api/serializers/account"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe API::V1::Serializers::Account do
  setup_spec

  describe ".from_account" do
    let(account) { register }
    let(actor) { account.actor.not_nil! }

    let(include_source) { false }

    subject { described_class.from_account(account, actor, include_source: include_source) }

    let(source) { subject.source.not_nil! }

    it "returns id" do
      expect(subject.id).to eq(actor.id.to_s)
    end

    it "returns username" do
      expect(subject.username).to eq(account.username)
    end

    it "returns acct for local actor" do
      expect(subject.acct).to eq(account.username)
    end

    it "returns url" do
      expect(subject.url).to eq("https://test.test/@#{account.username}")
    end

    context "with urls" do
      before_each { actor.assign(urls: ["https://remote/@user"]).save }

      it "returns url from urls array" do
        expect(subject.url).to eq("https://remote/@user")
      end
    end

    it "returns uri" do
      expect(subject.uri).to eq(actor.iri)
    end

    it "returns display_name" do
      expect(subject.display_name).to eq("")
    end

    it "returns note" do
      expect(subject.note).to eq("")
    end

    it "returns fallback avatar" do
      expect(subject.avatar).to match(/\/images\/avatars\/color-\d+\.png/)
    end

    it "returns fallback avatar_static" do
      expect(subject.avatar_static).to match(/\/images\/avatars\/color-\d+\.png/)
    end

    it "returns header" do
      expect(subject.header).to eq("")
    end

    it "returns header_static" do
      expect(subject.header_static).to eq("")
    end

    it "returns locked" do
      expect(subject.locked).to eq(!account.auto_approve_followers)
    end

    it "returns fields" do
      expect(subject.fields).to be_empty
    end

    it "returns emojis" do
      expect(subject.emojis).to be_empty
    end

    it "returns bot" do
      expect(subject.bot).to be_false
    end

    it "returns group" do
      expect(subject.group).to be_false
    end

    it "returns discoverable" do
      expect(subject.discoverable).to be_true
    end

    it "returns indexable" do
      expect(subject.indexable).to be_false
    end

    it "returns created_at" do
      expect(subject.created_at).to eq(actor.created_at.to_rfc3339)
    end

    it "returns last_status_at" do
      expect(subject.last_status_at).to be_nil
    end

    it "returns statuses_count" do
      expect(subject.statuses_count).to eq(0)
    end

    it "returns followers_count" do
      expect(subject.followers_count).to eq(0)
    end

    it "returns following_count" do
      expect(subject.following_count).to eq(0)
    end

    it "returns source" do
      expect(subject.source).to be_nil
    end

    context "with `include_source: true`" do
      let(include_source) { true }

      it "returns attribution_domains" do
        expect(source.attribution_domains).to be_empty
      end

      it "returns note" do
        expect(source.note).to eq("")
      end

      it "returns fields" do
        expect(source.fields).to be_empty
      end

      it "returns privacy" do
        expect(source.privacy).to eq("public")
      end

      it "returns sensitive" do
        expect(source.sensitive).to be_false
      end

      it "returns language in source" do
        expect(source.language).to eq(account.language)
      end

      it "returns follow_requests_count" do
        expect(source.follow_requests_count).to eq(0)
      end

      it "returns indexable" do
        expect(source.indexable).to be_false
      end

      it "returns quote_policy" do
        expect(source.quote_policy).to eq("approval")
      end
    end

    context "with actor attachments" do
      before_each do
        actor.assign(
          attachments: [
            ActivityPub::Actor::Attachment.new(name: "Website", type: "PropertyValue", value: "https://example.com"),
          ],
        ).save
      end

      it "includes fields" do
        expect(subject.fields.size).to eq(1)
      end

      it "returns name" do
        expect(subject.fields.first.name).to eq("Website")
      end

      it "returns value" do
        expect(subject.fields.first.value).to eq("https://example.com")
      end
    end

    context "with actor display name" do
      before_each { actor.assign(name: "Test User").save }

      it "returns display_name" do
        expect(subject.display_name).to eq("Test User")
      end
    end

    context "with actor summary" do
      before_each { actor.assign(summary: "<p>A bio</p>").save }

      it "returns note" do
        expect(subject.note).to eq("<p>A bio</p>")
      end

      context "in source" do
        let(include_source) { true }

        it "returns note" do
          expect(source.note).to eq("A bio")
        end
      end
    end

    context "with actor icon" do
      before_each { actor.assign(icon: "https://example.com/avatar.png").save }

      it "returns avatar" do
        expect(subject.avatar).to eq("https://example.com/avatar.png")
      end

      it "returns avatar_static" do
        expect(subject.avatar_static).to eq("https://example.com/avatar.png")
      end
    end

    context "with actor image" do
      before_each { actor.assign(image: "https://example.com/header.png").save }

      it "returns the header" do
        expect(subject.header).to eq("https://example.com/header.png")
      end

      it "returns the header_static" do
        expect(subject.header_static).to eq("https://example.com/header.png")
      end
    end

    context "with followers" do
      let_create(:actor, named: :follower)

      before_each { do_follow(follower, actor) }

      it "returns followers_count" do
        expect(subject.followers_count).to eq(1)
      end
    end

    context "with following" do
      let_create(:actor, named: :following)

      before_each { do_follow(actor, following) }

      it "returns following count" do
        expect(subject.following_count).to eq(1)
      end
    end

    context "with posts" do
      let(published) { Time.utc(2024, 6, 15, 12, 0, 0) }
      let_build(:note, attributed_to: actor, published: published, visible: true, local: true)
      let_build(:create, actor: actor, object: note)

      before_each { put_in_outbox(actor, create) }

      it "returns statuses_count" do
        expect(subject.statuses_count).to eq(1)
      end

      it "returns last_status_at as date string" do
        expect(subject.last_status_at).to eq("2024-06-15")
      end
    end

    context "with locked account" do
      before_each { account.assign(auto_approve_followers: false).save }

      it "returns locked" do
        expect(subject.locked).to be_true
      end
    end

    context "with Service actor type" do
      before_each { actor.assign(type: "ActivityPub::Actor::Service").save }

      it "returns bot" do
        expect(subject.bot).to be_true
      end
    end

    context "with Application actor type" do
      before_each { actor.assign(type: "ActivityPub::Actor::Application").save }

      it "returns bot" do
        expect(subject.bot).to be_true
      end
    end

    context "with Group actor type" do
      before_each { actor.assign(type: "ActivityPub::Actor::Group").save }

      it "returns group" do
        expect(subject.group).to be_true
      end
    end

    context "with pending follow requests" do
      let_create(:actor, named: :requester, local: true)
      let_create!(:follow_relationship, confirmed: false, actor: requester, object: actor)

      let(include_source) { true }

      it "returns follow_requests_count" do
        expect(source.follow_requests_count).to eq(1)
      end
    end

    context "with manually_approve_quotes disabled" do
      before_each { account.assign(manually_approve_quotes: false).save }

      let(include_source) { true }

      it "returns public for quote_policy" do
        expect(source.quote_policy).to eq("public")
      end
    end

    context "with manually_approve_quotes enabled" do
      before_each { account.assign(manually_approve_quotes: true).save }

      let(include_source) { true }

      it "returns approval for quote_policy" do
        expect(source.quote_policy).to eq("approval")
      end
    end
  end

  describe ".from_actor" do
    let_create(:actor, username: "remoteuser", local: false)

    subject { described_class.from_actor(actor) }

    it "returns id" do
      expect(subject.id).to eq(actor.id.to_s)
    end

    it "returns username" do
      expect(subject.username).to eq("remoteuser")
    end

    it "returns acct for remote actor" do
      expect(subject.acct).to eq("remoteuser@remote")
    end

    it "returns url" do
      expect(subject.url).to eq(actor.iri)
    end

    context "with urls" do
      before_each { actor.assign(urls: ["https://remote/@user"]).save }

      it "returns url from urls array" do
        expect(subject.url).to eq("https://remote/@user")
      end
    end

    it "returns uri" do
      expect(subject.uri).to eq(actor.iri)
    end

    it "returns display_name" do
      expect(subject.display_name).to eq("")
    end

    it "returns note" do
      expect(subject.note).to eq("")
    end

    it "returns fallback avatar" do
      expect(subject.avatar).to match(/\/images\/avatars\/color-\d+\.png/)
    end

    it "returns fallback avatar_static" do
      expect(subject.avatar_static).to match(/\/images\/avatars\/color-\d+\.png/)
    end

    it "returns header" do
      expect(subject.header).to eq("")
    end

    it "returns header_static" do
      expect(subject.header_static).to eq("")
    end

    it "returns locked as false" do
      expect(subject.locked).to be_false
    end

    it "returns fields" do
      expect(subject.fields).to be_empty
    end

    it "returns emojis" do
      expect(subject.emojis).to be_empty
    end

    it "returns bot" do
      expect(subject.bot).to be_false
    end

    it "returns group" do
      expect(subject.group).to be_false
    end

    it "returns discoverable" do
      expect(subject.discoverable).to be_true
    end

    it "returns indexable" do
      expect(subject.indexable).to be_false
    end

    it "returns created_at" do
      expect(subject.created_at).to eq(actor.created_at.to_rfc3339)
    end

    it "returns last_status_at" do
      expect(subject.last_status_at).to be_nil
    end

    it "returns statuses_count" do
      expect(subject.statuses_count).to eq(0)
    end

    it "returns followers_count" do
      expect(subject.followers_count).to eq(0)
    end

    it "returns following_count" do
      expect(subject.following_count).to eq(0)
    end

    it "returns source" do
      expect(subject.source).to be_nil
    end

    context "with actor attachments" do
      before_each do
        actor.assign(
          attachments: [
            ActivityPub::Actor::Attachment.new(name: "Website", type: "PropertyValue", value: "https://example.com"),
          ],
        ).save
      end

      it "includes fields" do
        expect(subject.fields.size).to eq(1)
      end

      it "returns name" do
        expect(subject.fields.first.name).to eq("Website")
      end

      it "returns value" do
        expect(subject.fields.first.value).to eq("https://example.com")
      end
    end

    context "with actor display name" do
      before_each { actor.assign(name: "Remote User").save }

      it "returns display_name" do
        expect(subject.display_name).to eq("Remote User")
      end
    end

    context "with actor summary" do
      before_each { actor.assign(summary: "<p>A remote bio</p>").save }

      it "returns note" do
        expect(subject.note).to eq("<p>A remote bio</p>")
      end
    end

    context "with actor icon" do
      before_each { actor.assign(icon: "https://remote/avatar.png").save }

      it "returns avatar" do
        expect(subject.avatar).to eq("https://remote/avatar.png")
      end

      it "returns avatar_static" do
        expect(subject.avatar_static).to eq("https://remote/avatar.png")
      end
    end

    context "with actor image" do
      before_each { actor.assign(image: "https://remote/header.png").save }

      it "returns header" do
        expect(subject.header).to eq("https://remote/header.png")
      end

      it "returns header_static" do
        expect(subject.header_static).to eq("https://remote/header.png")
      end
    end

    context "with followers" do
      let_create(:actor, named: :follower, local: true)

      before_each { do_follow(follower, actor) }

      it "returns followers_count" do
        expect(subject.followers_count).to eq(1)
      end
    end

    context "with following" do
      let_create(:actor, named: :following, local: true)

      before_each { do_follow(actor, following) }

      it "returns following count" do
        expect(subject.following_count).to eq(1)
      end
    end

    context "with posts" do
      let(published) { Time.utc(2024, 6, 15, 12, 0, 0) }
      let_build(:note, attributed_to: actor, published: published, visible: true, local: false)
      let_build(:create, actor: actor, object: note)

      before_each { put_in_outbox(actor, create) }

      it "returns statuses_count" do
        expect(subject.statuses_count).to eq(1)
      end

      it "returns last_status_at as date string" do
        expect(subject.last_status_at).to eq("2024-06-15")
      end
    end

    context "with Service actor type" do
      before_each { actor.assign(type: "ActivityPub::Actor::Service").save }

      it "returns bot" do
        expect(subject.bot).to be_true
      end
    end

    context "with Application actor type" do
      before_each { actor.assign(type: "ActivityPub::Actor::Application").save }

      it "returns bot" do
        expect(subject.bot).to be_true
      end
    end

    context "with Group actor type" do
      before_each { actor.assign(type: "ActivityPub::Actor::Group").save }

      it "returns group" do
        expect(subject.group).to be_true
      end
    end
  end

  describe "#to_json" do
    let(account) { register }
    let(actor) { account.actor.not_nil! }

    let(include_source) { false }

    subject { described_class.from_account(account, actor, include_source: include_source) }

    it "produces valid JSON with all required fields" do
      json = JSON.parse(subject.to_json)
      expect(json["id"]).to eq(actor.id.to_s)
      expect(json["username"]).to eq(account.username)
      expect(json["acct"]).to eq(account.username)
      expect(json["url"]).to eq("https://test.test/@#{account.username}")
      expect(json["uri"]).to eq(actor.iri)
      expect(json["display_name"]).to eq("")
      expect(json["note"]).to eq("")
      expect(json["avatar"].as_s).to match(/\/images\/avatars\/color-\d+\.png/)
      expect(json["avatar_static"].as_s).to match(/\/images\/avatars\/color-\d+\.png/)
      expect(json["header"]).to eq("")
      expect(json["header_static"]).to eq("")
      expect(json["locked"]).to eq(!account.auto_approve_followers)
      expect(json["fields"].as_a).to be_empty
      expect(json["emojis"].as_a).to be_empty
      expect(json["bot"]).to be_false
      expect(json["group"]).to be_false
      expect(json["discoverable"]).to be_true
      expect(json["indexable"]).to be_false
      expect(json["created_at"]).to eq(actor.created_at.to_rfc3339)
      expect(json["last_status_at"]).to eq(nil)
      expect(json["statuses_count"]).to eq(0)
      expect(json["followers_count"]).to eq(0)
      expect(json["following_count"]).to eq(0)
    end

    context "with `include_source: true`" do
      let(include_source) { true }

      it "includes source field with expected values" do
        json = JSON.parse(subject.to_json)
        expect(json["source"]["attribution_domains"].as_a).to be_empty
        expect(json["source"]["note"]).to eq("")
        expect(json["source"]["fields"].as_a).to be_empty
        expect(json["source"]["privacy"]).to eq("public")
        expect(json["source"]["sensitive"]).to be_false
        expect(json["source"]["language"]).to eq(account.language)
        expect(json["source"]["follow_requests_count"]).to eq(0)
        expect(json["source"]["indexable"]).to be_false
        expect(json["source"]["quote_policy"]).to eq("approval")
      end
    end
  end
end
