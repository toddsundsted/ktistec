require "../../../../src/models/oauth2/provider/access_token"
require "../../../../src/models/oauth2/provider/client"
require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe OAuth2::Provider::Client do
  setup_spec

  let(account) { register }

  let_create!(oauth2_provider_client, named: client)

  let_create!(oauth2_provider_access_token, named: access_token, client: client, account: account)

  it "has many access tokens" do
    expect(client.access_tokens.first).to be_a(OAuth2::Provider::AccessToken)
  end

  describe "validations" do
    it "validates client name is present" do
      client.assign(client_name: "   ")
      expect(client.valid?).to be_false
      expect(client.errors.keys).to contain("client_name")
    end

    it "validates redirect URIs is present" do
      client.assign(redirect_uris: "   ")
      expect(client.valid?).to be_false
      expect(client.errors.keys).to contain("redirect_uris")
    end

    it "validates redirect URIs have valid format" do
      client.assign(redirect_uris: "invalid-uri")
      expect(client.valid?).to be_false
      expect(client.errors.keys).to contain("redirect_uris")
    end

    it "validates redirect URIs have scheme" do
      client.assign(redirect_uris: "//example.com/callback")
      expect(client.valid?).to be_false
      expect(client.errors.keys).to contain("redirect_uris")
    end

    it "validates redirect URIs have host" do
      client.assign(redirect_uris: "https:///callback")
      expect(client.valid?).to be_false
      expect(client.errors.keys).to contain("redirect_uris")
    end

    it "validates multiple redirect URIs" do
      client.assign(redirect_uris: "https://example.com/callback invalid-uri https://app.example.com/auth")
      expect(client.valid?).to be_false
      expect(client.errors.keys).to contain("redirect_uris")
    end

    it "accepts valid redirect URIs" do
      client.assign(redirect_uris: "https://example.com/callback https://app.example.com/auth")
      expect(client.valid?).to be_true
    end
  end

  describe "normalizations" do
    it "normalizes redirect URIs to single spaces" do
      client.assign(redirect_uris: "https://example.com/callback    https://app.example.com/auth  https://third.com").save
      expect(client.redirect_uris).to eq("https://example.com/callback https://app.example.com/auth https://third.com")
    end

    it "trims leading and trailing whitespace" do
      client.assign(redirect_uris: "  https://example.com/callback https://app.example.com/auth  ").save
      expect(client.redirect_uris).to eq("https://example.com/callback https://app.example.com/auth")
    end
  end
end
