require "../framework"

class HomeController
  include Balloon::Controller

  skip_auth ["/"], GET, POST

  get "/" do |env|
    if !Balloon.host?
      _host = ""
      error = nil

      if accepts?("text/html")
        env.response.content_type = "text/html"
        render "src/views/home/step_1.html.ecr", "src/views/layouts/default.html.ecr"
      else
        env.response.content_type = "application/json"
        render "src/views/home/step_1.json.ecr"
      end
    elsif (accounts = Account.all).empty?
      account = Account.new("", "")
      actor = ActivityPub::Actor.new

      if accepts?("text/html")
        env.response.content_type = "text/html"
        render "src/views/home/step_2.html.ecr", "src/views/layouts/default.html.ecr"
      else
        env.response.content_type = "application/json"
        render "src/views/home/step_2.json.ecr"
      end
    else
      if accepts?("text/html")
        env.response.content_type = "text/html"
        render "src/views/home/index.html.ecr", "src/views/layouts/default.html.ecr"
      else
        env.response.content_type = "application/json"
        render "src/views/home/index.json.ecr"
      end
    end
  end

  post "/" do |env|
    if !Balloon.host?
      begin
        Balloon.host = host_param(env)

        if accepts?("text/html")
          env.redirect home_path
        else
          env.redirect home_path
        end
      rescue ex : Exception
        _host = host_param(env)
        error = ex.message

        if accepts?("text/html")
          env.response.content_type = "text/html"
          render "src/views/home/step_1.html.ecr", "src/views/layouts/default.html.ecr"
        else
          env.response.content_type = "application/json"
          render "src/views/home/step_1.json.ecr"
        end
      end
    elsif (accounts = Account.all).empty?
      account = Account.new(**params(env))
      actor = ActivityPub::Actor.new(**params(env))
      actor.iri = account.iri
      if account.valid? && actor.valid?
        keypair = OpenSSL::RSA.generate(2048, 17)
        actor.pem_public_key = keypair.public_key.to_pem
        actor.pem_private_key = keypair.to_pem

        account.save
        actor.save

        session = Session.new(account).save
        payload = {sub: account.id, jti: session.session_key, iat: Time.utc}
        jwt = Balloon::JWT.encode(payload)

        if accepts?("text/html")
          env.response.cookies["AuthToken"] = jwt
          env.redirect actor_path(account)
        else
          env.response.content_type = "application/json"
          {jwt: jwt}.to_json
        end
      else
        if accepts?("text/html")
          env.response.content_type = "text/html"
          render "src/views/home/step_2.html.ecr", "src/views/layouts/default.html.ecr"
        else
          env.response.content_type = "application/json"
          render "src/views/home/step_2.json.ecr"
        end
      end
    else
      not_found
    end
  rescue KeyError
    env.redirect home_path
  end

  private def self.host_param(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    params["host"].as(String)
  end

  private def self.params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    {
      username: params["username"].as(String),
      password: params["password"].as(String),
      name: params["name"].as(String),
      summary: params["summary"].as(String)
    }
  end
end
