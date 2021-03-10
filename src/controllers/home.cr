require "../framework/controller"
require "../models/activity_pub/activity/follow"
require "../models/activity_pub/actor/person"

class HomeController
  include Ktistec::Controller

  skip_auth ["/"], GET, POST

  get "/" do |env|
    if !Ktistec.host?
      _host = _site = ""
      error = nil

      ok "home/step_1"
    elsif (accounts = Account.all).empty?
      account = Account.new("", "")
      actor = ActivityPub::Actor.new

      ok "home/step_2"
    elsif (account = env.account?).nil?
      activities = ActivityPub::Actor.local_timeline(*pagination_params(env))

      ok "home/index"
    else
      redirect actor_path(account)
    end
  end

  post "/" do |env|
    if !Ktistec.host? || !Ktistec.site?
      begin
        Ktistec.host, Ktistec.site = step_1_params(env)

        if accepts?("text/html")
          redirect home_path
        else
          redirect home_path
        end
      rescue ex : Exception
        error = ex.message
        _host, _site = step_1_params(env)

        ok "home/step_1"
      end
    elsif (accounts = Account.all).empty?
      account = Account.new(**step_2_params(env))
      actor = ActivityPub::Actor::Person.new(**step_2_params(env))

      if account.valid? && actor.valid?
        keypair = OpenSSL::RSA.generate(2048, 17)
        actor.pem_public_key = keypair.public_key.to_pem
        actor.pem_private_key = keypair.to_pem

        account.assign(actor: actor).save

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
    [
      params["host"].as(String),
      params["site"].as(String)
    ]
  end

  private def self.step_2_params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    {
      username: params["username"].as(String),
      password: params["password"].as(String),
      name: params["name"].as(String),
      summary: params["summary"].as(String)
    }
  end
end
