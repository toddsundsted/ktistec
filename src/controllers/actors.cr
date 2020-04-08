require "../framework/controller"

class ActorsController
  include Balloon::Controller

  skip_auth ["/actors/:username"]

  get "/actors/:username" do |env|
    username = env.params.url["username"]

    actor = Actor.find(username: username)

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/actors/show.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/actors/json.ecr"
    end
  rescue ex: DB::Error
    not_found if ex.message == "no rows"
    raise ex
  end
end
