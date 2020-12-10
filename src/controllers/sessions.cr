require "../framework/controller"

class SessionsController
  include Ktistec::Controller

  skip_auth ["/sessions"], GET, POST

  get "/sessions" do |env|
    message = username = password = nil

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/pages/login.html.ecr", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/json"
      {username: username, password: password}.to_json
    end
  end

  post "/sessions" do |env|
    username, password = params(env)

    if account = account?(username, password)
      session = Session.new(account).save
      payload = {jti: session.session_key, iat: Time.utc}
      jwt = Ktistec::JWT.encode(payload)

      if accepts?("text/html")
        env.response.cookies["AuthToken"] = jwt
        env.redirect actor_path(account)
      else
        env.response.content_type = "application/json"
        {jwt: jwt}.to_json
      end
    else
      message = "invalid username or password"

      env.response.status_code = 403
      if accepts?("text/html")
        env.response.content_type = "text/html"
        render "src/views/pages/login.html.ecr", "src/views/layouts/default.html.ecr"
      else
        env.response.content_type = "application/json"
        {msg: message, username: username, password: password}.to_json
      end
    end
  rescue KeyError
    env.redirect sessions_path
  end

  delete "/sessions" do |env|
    if (session = env.session?)
      session.destroy
    end
    env.redirect sessions_path
  end

  private def self.params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    ["username", "password"].map { |p| params[p].as(String) }
  end

  private def self.account?(username, password)
    account = Account.find(username: username)
    if account.valid_password?(password)
      account
    end
  rescue
    nil
  end
end
