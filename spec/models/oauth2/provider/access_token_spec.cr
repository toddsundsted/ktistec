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
end
