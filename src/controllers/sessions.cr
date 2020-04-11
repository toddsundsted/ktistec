require "../framework"

class SessionsController
  include Balloon::Controller

  skip_auth ["/sessions"], GET, POST

  get "/sessions" do |env|
    message = username = password = nil

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/pages/login.ecr"
    else
      env.response.content_type = "application/json"
      {username: username, password: password}.to_json
    end
  end

  post "/sessions" do |env|
    username, password = params(env)

    if actor = actor?(username, password)
      session = Session.new(actor).save
      payload = {sub: actor.id, jti: session.session_key, iat: Time.utc}
      jwt = Balloon::JWT.encode(payload)

      if accepts?("text/html")
        env.response.cookies["AuthToken"] = jwt
        env.redirect "/actors/#{actor.username}"
      else
        env.response.content_type = "application/json"
        {jwt: jwt}.to_json
      end
    else
      message = "invalid username or password"

      env.response.status_code = 403
      if accepts?("text/html")
        env.response.content_type = "text/html"
        render "src/views/pages/login.ecr"
      else
        env.response.content_type = "application/json"
        {msg: message, username: username, password: password}.to_json
      end
    end
  rescue KeyError
    env.redirect "/sessions"
  end

  post "/sessions/forget" do |env|
    if session = env.session?
      session.destroy
    end
    env.redirect "/sessions"
  end

  private def self.params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    ["username", "password"].map { |p| params[p].as(String) }
  end

  private def self.actor?(username, password)
    actor = Actor.find(username: username)
    if actor.valid_password?(password)
      actor
    end
  rescue
    nil
  end
end
