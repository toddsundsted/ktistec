require "../framework/controller"

class AccountsController
  include Balloon::Controller

  skip_auth ["/accounts/:username"]

  get "/accounts/:username" do |env|
    username = env.params.url["username"]

    account = Account.find(username: username)

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/accounts/show.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/accounts/json.ecr"
    end
  rescue Balloon::Model::NotFound
    not_found
  end
end
