require "../framework/controller"

# Internal endpoints.
#
class InternalController
  include Ktistec::Controller

  skip_auth ["/_internal/authenticated"], GET

  get "/_internal/authenticated" do |env|
    unauthorized unless env.account?
    halt env, status_code: 204, response: ""
  end
end
