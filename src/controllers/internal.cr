require "../framework/controller"

# Internal endpoints.
#
class InternalController
  include Ktistec::Controller

  skip_auth ["/_internal/authenticated"], GET

  get "/_internal/authenticated" do |env|
    if (account = env.account?)
      env.response.headers["X-Username"] = account.username
      halt env, status_code: 204, response: ""
    else
      unauthorized
    end
  end
end
