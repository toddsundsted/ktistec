require "../framework/controller"
require "../models/activity_pub/object/note"

class ObjectsController
  include Ktistec::Controller

  skip_auth ["/objects/:id"], GET

  macro depth(object)
    "depth-#{Math.min({{object}}.depth, 9)}"
  end

  macro iri_param
    "#{host}/objects/#{env.params.url["id"]}"
  end

  macro id_param
    env.params.url["id"].to_i64
  end

  get "/actors/:username/drafts" do |env|
    unless (account = get_account(env))
      not_found
    end
    unless env.account == account
      forbidden
    end

    drafts = account.actor.drafts(*pagination_params(env))

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/objects/index.html.slang", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/objects/index.json.ecr"
    end
  end

  post "/objects" do |env|
    object = ActivityPub::Object::Note.new(
      iri: "#{host}/objects/#{id}",
      attributed_to: env.account.actor
    )

    object.assign(params(env)).save

    env.created edit_object_path(object)
  end

  get "/objects/:id" do |env|
    unless (object = get_object(env, iri_param))
      not_found
    end

    env.redirect edit_object_path if object.draft?

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/objects/object.html.slang", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/objects/object.json.ecr"
    end
  end

  get "/objects/:id/edit" do |env|
    unless (object = get_draft(env, iri_param))
      not_found
    end

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/objects/edit.html.slang", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/objects/object.json.ecr"
    end
  end

  post "/objects/:id" do |env|
    unless (object = get_draft(env, iri_param))
      not_found
    end

    object.assign(params(env)).save

    env.redirect object_path(object)
  end

  delete "/objects/:id" do |env|
    unless (object = get_draft(env, iri_param))
      not_found
    end

    object.delete

    env.redirect back_path
  end

  get "/remote/objects/:id" do |env|
    unless (object = get_object(env, id_param))
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
    unless (object = get_object(env, id_param))
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

  private def self.params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    enhancements = Ktistec::Util.enhance params["content"].as(String)
    {
      "media_type" => "text/html",
      "content" => enhancements.content,
      "attachments" => enhancements.attachments
    }
  end

  private def self.get_draft(env, iri_or_id)
    if (object = ActivityPub::Object.find?(iri_or_id))
      if env.account.actor == object.attributed_to? && object.draft?
        object
      end
    end
  end

  private def self.get_object(env, iri_or_id)
    if (object = ActivityPub::Object.find?(iri_or_id))
      if object.visible ||
         ((account = env.account?) &&
          ((account.actor == object.attributed_to? && (!env.request.path.starts_with?("/remote/") || !object.draft?)) ||
           account.actor.in_inbox?(object)))
        object
      end
    end
  end

  private def self.get_account(env)
    Account.find?(username: env.params.url["username"]?)
  end
end
