require "../../framework/controller"
require "../../models/account"
require "../../models/activity_pub/actor/person"

module Admin
  class AccountsController
    include Ktistec::Controller

    get "/admin/accounts" do |env|
      accounts = Account.all
      ok "admin/accounts/index", env: env, accounts: accounts
    end

    get "/admin/accounts/new" do |env|
      account = Account.new(username: "", password: "")
      actor = ActivityPub::Actor.new

      account.actor = actor

      ok "admin/accounts/new", env: env, account: account, actor: actor
    end

    post "/admin/accounts" do |env|
      host = Ktistec.host

      username = env.params.body["username"]
      password = env.params.body["password"]
      language = env.params.body["language"]
      timezone = env.params.body["timezone"]
      name = env.params.body["name"]
      summary = env.params.body["summary"]

      iri = "#{host}/actors/#{username}"

      account = Account.new(
        username: username,
        password: password,
        language: language,
        timezone: timezone,
      )
      actor = ActivityPub::Actor::Person.new(
        iri: iri,
        username: username,
        name: name,
        summary: summary,
      )

      account.actor = actor

      if account.valid?
        account.save

        redirect "/admin/accounts"
      else
        unprocessable_entity "admin/accounts/new", env: env, account: account, actor: actor
      end
    end
  end
end
