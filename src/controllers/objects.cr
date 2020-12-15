require "../framework/controller"

class ObjectsController
  include Ktistec::Controller

  skip_auth ["/objects/:id"], GET

  macro depth(object)
    "depth-#{Math.min({{object}}.depth, 9)}"
  end

  get "/objects/:id" do |env|
    iri = "#{host}/objects/#{env.params.url["id"]}"

    unless (object = get_object(env, iri))
      not_found
    end

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/objects/object.html.slang", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/objects/object.json.ecr"
    end
  end

  get "/remote/objects/:id" do |env|
    id = env.params.url["id"].to_i64

    unless (object = get_object(env, id))
      not_found
    end

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/objects/object.html.slang", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/objects/object.json.ecr"
    end
  end

  get "/remote/objects/:id/thread" do |env|
    id = env.params.url["id"].to_i64

    unless (object = get_object(env, id))
      not_found
    end

    thread = object.thread

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/objects/thread.html.slang", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/objects/thread.json.ecr"
    end
  end

  get "/remote/objects/:id/replies" do |env|
    id = env.params.url["id"].to_i64

    unless (object = get_object(env, id))
      not_found
    end

    ancestors = object.ancestors.tap(&.shift?)

    env.response.content_type = "text/html"
    render "src/views/objects/reply.html.slang", "src/views/layouts/default.html.ecr"
  end

  private def self.get_object(env, iri_or_id)
    if (object = ActivityPub::Object.find?(iri_or_id))
      if object.visible || env.account?.try(&.actor.in_inbox?(object))
        object
      end
    end
  end
end
