require "../framework/controller"

class ObjectsController
  include Balloon::Controller

  skip_auth ["/objects/:id"], GET

  macro depth(object)
    "depth-#{{{object}}.depth}"
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

    env.response.content_type = "text/html"
    render "src/views/objects/reply.html.slang", "src/views/layouts/default.html.ecr"
  end

  private def self.get_object(env, iri_or_id)
    if (object = ActivityPub::Object.find?(iri_or_id))
      if object.visible
        object
      elsif object.to.try(&.includes?(PUBLIC)) || object.cc.try(&.includes?(PUBLIC))
        object
      elsif (iri = env.current_account?.try(&.iri))
        if object.to.try(&.includes?(iri)) || object.cc.try(&.includes?(iri))
          object
        end
      end
    end
  end

  private PUBLIC = "https://www.w3.org/ns/activitystreams#Public"
end
