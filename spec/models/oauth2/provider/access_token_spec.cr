require "../../../../src/models/oauth2/provider/access_token"
require "../../../../src/models/oauth2/provider/client"
require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe OAuth2::Provider::AccessToken do
  setup_spec

  let(account) { register }

  let_create!(oauth2_provider_client, named: client)

  let_create!(oauth2_provider_access_token, named: access_token, client: client, account: account)

  it "belongs to an account" do
    expect(access_token.account.id).to eq(account.id)
  end

  it "belongs to a client" do
    expect(access_token.client.id).to eq(client.id)
  end

  describe ".find_by_token?" do
    it "returns the access token when found" do
      token = OAuth2::Provider::AccessToken.find_by_token?(access_token.token)
      expect(token.try(&.id)).to eq(access_token.id)
    end

    it "returns nil when not found" do
      token = OAuth2::Provider::AccessToken.find_by_token?("nonexistent_token")
      expect(token).to be_nil
    end
  end

  describe "#valid?" do
    context "when token has not expired" do
      let_build(oauth2_provider_access_token, named: valid_token, client: client, account: account, expires_at: Time.utc + 1.hour)

      it "returns true" do
        expect(valid_token.valid?).to be_true
      end
    end

    context "when token has expired" do
      let_build(oauth2_provider_access_token, named: expired_token, client: client, account: account, expires_at: Time.utc - 1.hour)

      it "returns false" do
        expect(expired_token.valid?).to be_false
      end
    end
  end

  describe "#has_mcp_scope?" do
    context "when scope includes 'mcp'" do
      let_create!(oauth2_provider_access_token, named: mcp_token, client: client, account: account, scope: "mcp read")

      it "returns true" do
        expect(mcp_token.has_mcp_scope?).to be_true
      end
    end

    context "when scope only contains 'mcp'" do
      let_create!(oauth2_provider_access_token, named: mcp_only_token, client: client, account: account, scope: "mcp")

      it "returns true" do
        expect(mcp_only_token.has_mcp_scope?).to be_true
      end
    end

    context "when scope does not include 'mcp'" do
      let_create!(oauth2_provider_access_token, named: no_mcp_token, client: client, account: account, scope: "read write")

      it "returns false" do
        expect(no_mcp_token.has_mcp_scope?).to be_false
      end
    end

    context "when scope is empty" do
      let_create!(oauth2_provider_access_token, named: empty_scope_token, client: client, account: account, scope: "")

      it "returns false" do
        expect(empty_scope_token.has_mcp_scope?).to be_false
      end
    end

    context "given a string with 'mcp' as a substring" do
      let_create!(oauth2_provider_access_token, named: mcp_substring_token, client: client, account: account, scope: "mcp123")

      it "returns false" do
        expect(mcp_substring_token.has_mcp_scope?).to be_false
      end
    end
  end
end
