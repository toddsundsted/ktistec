require "../framework/controller"

class SessionsController
  include Ktistec::Controller

  skip_auth ["/sessions"], GET, POST

  get "/sessions" do |env|
    message = username = password = nil

    ok "sessions/new", env: env, message: message, username: username, password: password
  end

  post "/sessions" do |env|
    username, password = params(env)

    if account = account?(username, password)
      session = env.new_session(account)
      jwt = session.generate_jwt

      if accepts?("text/html")
        redirect actor_path(account)
      else
        env.response.content_type = "application/json"
        {jwt: jwt}.to_json
      end
    else
      message = "invalid username or password"

      forbidden "sessions/new", env: env, message: message, username: username, password: password
    end
  rescue KeyError
    redirect sessions_path
  end

  delete "/sessions" do |env|
    if (session = env.session?)
      session.destroy
    end
    redirect sessions_path
  end

  private def self.params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    ["username", "password"].map { |p| params[p].as(String) }
  end

  private def self.account?(username, password)
    if (account = Account.find?(username: username)) && account.check_password(password)
      account
    end
  end
end
