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
      # get the redirect path from the cookie
      redirect_path = redirect_path_from_cookie(env) || actor_path(account)

      # clear the redirect cookie
      env.response.cookies["__Host-RedirectPath"] = HTTP::Cookie.new(
        name: "__Host-RedirectPath",
        value: "",
        path: "/",
        max_age: Time::Span.zero,
        http_only: true,
        secure: true,
      )

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

  # Reads and validates the redirect path in the cookie.
  #
  private def self.redirect_path_from_cookie(env) : String?
    value = env.request.cookies["__Host-RedirectPath"]?.try(&.value)
    unless value.nil? || value.empty?
      path = URI.decode(value)
      uri = URI.parse(path).normalize
      if uri.scheme.nil? && uri.host.nil?
        path
      end
    end
  end
end
