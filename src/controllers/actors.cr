require "../framework/controller"

class ActorsController
  include Balloon::Controller

  skip_auth ["/actors/:username"]

  get "/actors/:username" do |env|
    username = env.params.url["username"]

    actor = Account.find(username: username).actor

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/actors/show.ecr", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/actors/json.ecr"
    end
  rescue Balloon::Model::NotFound
    not_found
  end

  get "/remote/actors/:id" do |env|
    id = env.params.url["id"].to_i

    actor = ActivityPub::Actor.find(id)

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/actors/remote.html.ecr", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/actors/remote.json.ecr"
    end
  rescue Balloon::Model::NotFound
    not_found
  end
end
