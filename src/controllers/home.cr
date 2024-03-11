require "../framework/controller"
require "../models/activity_pub/activity/follow"
require "../models/activity_pub/actor/person"

class HomeController
  include Ktistec::Controller

  skip_auth ["/"], GET, POST

  get "/" do |env|
    if !Ktistec.settings.host.presence || !Ktistec.settings.site.presence
      settings = Ktistec.settings

      ok "home/step_1", env: env, settings: settings
    elsif (accounts = Account.all).empty?
      account = Account.new("", "")
      actor = ActivityPub::Actor.new

      account.actor = actor

      ok "home/step_2", env: env, account: account, actor: actor
    elsif (account = env.account?).nil?
      objects = ActivityPub::Object.public_posts(**pagination_params(env))

      ok "home/index", env: env, accounts: accounts, objects: objects
    else
      redirect actor_path(account)
    end
  end

  post "/" do |env|
    if !Ktistec.settings.host.presence || !Ktistec.settings.site.presence
      settings = Ktistec.settings.assign(step_1_params(env))

      if settings.valid?
        settings.save

        redirect home_path
      else
        unprocessable_entity "home/step_1", env: env, settings: settings
      end
    elsif (accounts = Account.all).empty?
      params = step_2_params(env)

      account = Account.new(params)
      actor = ActivityPub::Actor::Person.new(params)

      account.actor = actor

      if account.valid?
        account.save
        session = env.new_session(account)
        jwt = session.generate_jwt

        if accepts?("text/html")
          redirect actor_path(actor)
        else
          env.response.content_type = "application/json"
          {jwt: jwt}.to_json
        end
      else
        unprocessable_entity "home/step_2", env: env, account: account, actor: actor
      end
    else
      not_found
    end
  rescue KeyError
    redirect home_path
  end

  private def self.step_1_params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    {
      "host" => params["host"].as(String),
      "site" => params["site"].as(String)
    }
  end

  private def self.step_2_params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    {
      "username" => params["username"].as(String),
      "password" => params["password"].as(String),
      "name" => params["name"].as(String),
      "summary" => params["summary"].as(String),
      "timezone" => params["timezone"].as(String)
    }
  end
end
