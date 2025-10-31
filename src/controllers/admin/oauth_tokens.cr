require "../../framework/controller"
require "../../models/oauth2/provider/access_token"

module Admin
  class OAuthTokensController
    include Ktistec::Controller

    get "/admin/oauth/tokens" do |env|
      tokens = OAuth2::Provider::AccessToken.all
      ok "admin/oauth/tokens/index", env: env, tokens: tokens
    end

    delete "/admin/oauth/tokens/:id" do |env|
      id = env.params.url["id"]
      unless (token = OAuth2::Provider::AccessToken.find?(id: id))
        not_found
      end
      token.destroy
      redirect "/admin/oauth/tokens"
    end
  end
end
