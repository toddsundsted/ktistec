require "../framework/controller"
require "../views/view_helper"
require "../models/activity_pub/activity/follow"
require "../models/activity_pub/actor/person"

class HomeController
  include Ktistec::Controller
  include Ktistec::ViewHelper

  skip_auth ["/"], GET, POST

  get "/" do |env|
    if !Ktistec.settings.host.presence || !Ktistec.settings.site.presence
      settings = Ktistec.settings

      ok "home/step_1"
    elsif (accounts = Account.all).empty?
      account = Account.new("", "")
      actor = ActivityPub::Actor.new

      account.actor = actor

      ok "home/step_2"
    elsif (account = env.account?).nil?
      objects = ActivityPub::Object.timeline(*pagination_params(env))

      ok "home/index"
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
        ok "home/step_1"
      end
    elsif (accounts = Account.all).empty?
      params = step_2_params(env)

      account = Account.new(params)
      actor = ActivityPub::Actor::Person.new(params)

      account.actor = actor

      if account.valid?
        keypair = OpenSSL::RSA.generate(2048, 17)
        actor.pem_public_key = keypair.public_key.to_pem
        actor.pem_private_key = keypair.to_pem

        account.save

        session = Session.new(account).save
        payload = {jti: session.session_key, iat: Time.utc}
        jwt = Ktistec::JWT.encode(payload)

        if accepts?("text/html")
          env.response.cookies["AuthToken"] = jwt
          redirect actor_path(actor)
        else
          env.response.content_type = "application/json"
          {jwt: jwt}.to_json
        end
      else
        ok "home/step_2"
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
      "summary" => params["summary"].as(String)
    }
  end
end
