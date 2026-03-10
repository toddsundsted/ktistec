require "../../../src/api/serializers/application"
require "../../../src/models/oauth2/provider/client"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe API::V1::Serializers::Application do
  setup_spec

  describe ".from_client" do
    let_build(:oauth2_provider_client, named: :client, client_name: "Test Application", scope: "read write")

    context "with `include_secret: true`" do
      subject { described_class.from_client(client, include_secret: true) }

      it "maps client_name to name" do
        expect(subject.name).to eq("Test Application")
      end

      it "returns client_id" do
        expect(subject.client_id).to eq(client.client_id)
      end

      it "maps scope to scopes array" do
        expect(subject.scopes).to eq(["read", "write"])
      end

      it "returns redirect_uris as array" do
        expect(subject.redirect_uris).to eq(client.redirect_uris.split)
      end

      it "returns redirect_uri as string" do
        expect(subject.redirect_uri).to eq(client.redirect_uris.split.join("\n"))
      end

      it "includes client_secret" do
        expect(subject.client_secret).to eq(client.client_secret)
      end

      it "sets client_secret_expires_at to 0" do
        expect(subject.client_secret_expires_at).to eq(0)
      end

      it "sets vapid_key to empty string" do
        expect(subject.vapid_key).to eq("")
      end

      it "sets website to nil" do
        expect(subject.website).to be_nil
      end
    end

    context "with `include_secret: false`" do
      subject { described_class.from_client(client, include_secret: false) }

      it "excludes client_secret" do
        expect(subject.client_secret).to be_nil
      end

      it "excludes client_secret_expires_at" do
        expect(subject.client_secret_expires_at).to be_nil
      end

      it "excludes vapid_key" do
        expect(subject.vapid_key).to be_nil
      end
    end

    context "with website" do
      subject { described_class.from_client(client, website: "https://example.com") }

      it "returns the website" do
        expect(subject.website).to eq("https://example.com")
      end
    end

    context "with multiple redirect_uris" do
      before_each { client.assign(redirect_uris: "https://example.com/callback https://example.com/oauth") }

      subject { described_class.from_client(client) }

      it "returns newline-separated URIs in redirect_uri field" do
        expect(subject.redirect_uri).to eq("https://example.com/callback\nhttps://example.com/oauth")
      end

      it "returns all URIs in redirect_uris array" do
        expect(subject.redirect_uris).to eq(["https://example.com/callback", "https://example.com/oauth"])
      end
    end

    context "with new record" do
      subject { described_class.from_client(client) }

      it "maps client_id to id" do
        expect(subject.id).to eq(client.client_id)
      end
    end

    context "with saved client" do
      before_each { client.save }

      subject { described_class.from_client(client) }

      it "maps database id to id" do
        expect(subject.id).to eq(client.id.to_s)
      end
    end
  end

  describe "#to_json" do
    let_build(:oauth2_provider_client, named: :client, client_name: "Test Application", scope: "read write")

    subject { described_class.from_client(client, include_secret: true) }

    it "produces valid JSON with all required fields" do
      json = JSON.parse(subject.to_json)
      expect(json["id"]).to eq(client.client_id)
      expect(json["name"]).to eq("Test Application")
      expect(json["scopes"].as_a.map(&.as_s)).to eq(["read", "write"])
      expect(json["redirect_uris"].as_a.map(&.as_s)).to eq(client.redirect_uris.split)
      expect(json["redirect_uri"]).to eq(client.redirect_uris.split.join("\n"))
      expect(json["client_id"]).to eq(client.client_id)
      expect(json["client_secret"]).to eq(client.client_secret)
      expect(json["client_secret_expires_at"]).to eq(0)
      expect(json["vapid_key"]).to eq("")
      expect(json["website"]).to eq(nil)
    end
  end
end
