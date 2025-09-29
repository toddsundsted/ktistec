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

      params = params(env)
      username = params["username"]
      password = params["password"]
      language = params["language"]
      timezone = params["timezone"]
      name = params["name"]
      summary = params["summary"]

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

        if accepts?("text/html")
          redirect "/admin/accounts"
        else
          created "/admin/accounts", "admin/accounts/show", env: env, account: account
        end
      else
        unprocessable_entity "admin/accounts/new", env: env, account: account, actor: actor
      end
    end

    private def self.params(env)
      params = accepts?("text/html") ? env.params.body : env.params.json
      {
        "username" => params["username"].as(String),
        "password" => params["password"].as(String),
        "name" => params["name"].as(String),
        "summary" => params["summary"].as(String),
        "language" => params["language"].as(String),
        "timezone" => params["timezone"].as(String)
      }
    end
  end
end
