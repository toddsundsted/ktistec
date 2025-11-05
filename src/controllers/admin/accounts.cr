require "../../framework/controller"
require "../../models/account"
require "../../models/activity_pub/actor/person"

module Admin
  class AccountsController
    include Ktistec::Controller

    PERSON = ActivityPub::Actor::Person.to_s

    get "/admin/accounts" do |env|
      accounts = Account.all

      ok "admin/accounts/index", env: env, accounts: accounts
    end

    get "/admin/accounts/new" do |env|
      account = Account.new(username: "", password: "")
      actor = ActivityPub::Actor.new(type: PERSON)

      account.actor = actor

      ok "admin/accounts/new", env: env, account: account, actor: actor
    end

    post "/admin/accounts" do |env|
      host = Ktistec.host

      params = params(env)

      account = Account.new(params)
      actor = ActivityPub::Actor.new(params)

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
        "timezone" => params["timezone"].as(String),
        "auto_approve_followers" => params["auto_approve_followers"]?.in?("1", true) || false,
        "auto_follow_back" => params["auto_follow_back"]?.in?("1", true) || false,
        "type" => params["type"]?.try(&.as(String)) || PERSON,
      }
    end
  end
end
