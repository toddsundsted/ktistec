require "../framework/controller"

class ActorsController
  include Balloon::Controller

  skip_auth ["/actors/:username"]

  get "/actors/:username" do |env|
    username = env.params.url["username"]

    actor = Account.find(username: username).actor

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/actors/show.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/actors/json.ecr"
    end
  rescue Balloon::Model::NotFound
    not_found
  end
end
