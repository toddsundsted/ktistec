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
end
