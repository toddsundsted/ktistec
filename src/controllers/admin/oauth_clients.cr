require "../../framework/controller"
require "../../models/oauth2/provider/client"

require "random"

module Admin
  class OAuthClientsController
    include Ktistec::Controller

    get "/admin/oauth/clients" do |env|
      clients = OAuth2::Provider::Client.all
      new_client = OAuth2::Provider::Client.new(
        client_name: "",
        client_id: "",
        client_secret: "",
        redirect_uris: "",
        scope: "mcp",
        manual: true
      )
      ok "admin/oauth/clients/index", env: env, clients: clients, new_client: new_client
    end

    post "/admin/oauth/clients" do |env|
      clients = OAuth2::Provider::Client.all
      new_client = OAuth2::Provider::Client.new(
        client_id: Random::Secure.urlsafe_base64,
        client_secret: Random::Secure.urlsafe_base64,
        client_name: env.params.body["client_name"]? || "",
        redirect_uris: env.params.body["redirect_uris"]? || "",
        scope: "mcp",
        manual: true
      )
      if new_client.valid?
        new_client.save
        redirect "/admin/oauth/clients"
      else
        unprocessable_entity "admin/oauth/clients/index", env: env, clients: clients, new_client: new_client
      end
    end

    delete "/admin/oauth/clients/:id" do |env|
      id = env.params.url["id"]
      unless (client = OAuth2::Provider::Client.find?(id: id))
        not_found
      end
      client.destroy
      redirect "/admin/oauth/clients"
    end
  end
end
