require "../framework/controller"
require "../services/description_enhancer"
require "../models/activity_pub/activity/follow"
require "../models/activity_pub/actor/person"
require "../utils/rss"

class HomeController
  include Ktistec::Controller

  PERSON = ActivityPub::Actor::Person.to_s

  skip_auth ["/"], GET, POST
  skip_auth ["/feed.rss"], GET
  skip_auth ["/robots.txt"], GET
  skip_auth ["/license"], GET

  get "/" do |env|
    if !Ktistec.settings.host.presence || !Ktistec.settings.site.presence
      settings = Ktistec.settings

      ok "home/step_1", env: env, settings: settings
    elsif (accounts = Account.all).empty?
      # `username` and `password` properties are not nilable
      account = Account.new(username: "", password: "")
      actor = ActivityPub::Actor.new(type: PERSON)

      account.actor = actor

      ok "home/step_2", env: env, account: account, actor: actor
    elsif (account = env.account?).nil?
      objects = ActivityPub::Object.public_posts(**pagination_params(env))

      ok "home/index", env: env, accounts: accounts, objects: objects
    else
      redirect actor_path(account)
    end
  end

  get "/feed.rss" do |env|
    objects = ActivityPub::Object.public_posts(**pagination_params(env))

    site_name = Ktistec.site
    site_host = Ktistec.host

    env.response.content_type = "application/rss+xml; charset=utf-8"

    Ktistec::RSS.generate_rss_feed(
      objects, site_name, site_host,
      "#{site_name}: RSS Feed"
    )
  end

  get "/robots.txt" do |env|
    env.response.content_type = "text/plain"
    render "src/views/pages/robots.txt.ecr"
  end

  get "/license" do |env|
    env.response.content_type = "text/html; charset=utf-8"
    render "src/views/pages/license.html.slang", "src/views/layouts/default.html.ecr"
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
    elsif Account.all.empty?
      params = step_2_params(env)

      account = Account.new(params)
      actor = ActivityPub::Actor.new(params)

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
      "site" => params["site"].as(String),
    }
  end

  private def self.step_2_params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    {
      "username"               => params["username"].as(String),
      "password"               => params["password"].as(String),
      "name"                   => params["name"].as(String),
      "summary"                => params["summary"].as(String),
      "language"               => params["language"].as(String),
      "timezone"               => params["timezone"].as(String),
      "auto_approve_followers" => params["auto_approve_followers"]?.in?("1", true) || false,
      "auto_follow_back"       => params["auto_follow_back"]?.in?("1", true) || false,
      "type"                   => params["type"]?.try(&.as(String)) || PERSON,
    }
  end
end
