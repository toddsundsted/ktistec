require "../framework/controller"

class SessionsController
  include Ktistec::Controller

  skip_auth ["/sessions"], GET, POST

  get "/sessions" do |env|
    ok "sessions/new", env: env, message: nil, username: nil, password: nil
  end

  post "/sessions" do |env|
    username, password = params(env)

    if (account = account?(username, password))
      # get the `redirect_after_auth_path` from the old session.
      redirect_path = env.session.string?("redirect_after_auth_path") || actor_path(account)

      session = env.new_session(account)
      jwt = session.generate_jwt

      if accepts?("text/html")
        redirect redirect_path
      else
        env.response.content_type = "application/json"
        {jwt: jwt, redirect_path: redirect_path}.to_json
      end
    else
      forbidden "sessions/new", env: env, message: "invalid username or password", username: username, password: password
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
