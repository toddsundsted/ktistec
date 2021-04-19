require "../framework/controller"
require "../views/view_helper"
require "../models/activity_pub/object/note"

class ObjectsController
  include Ktistec::Controller
  extend Ktistec::ViewHelper

  skip_auth ["/objects/:id", "/objects/:id/thread"], GET

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

    ok "objects/index"
  end

  post "/objects" do |env|
    object = ActivityPub::Object::Note.new(
      iri: "#{host}/objects/#{id}",
      attributed_to: env.account.actor
    )

    unless object.assign(params(env)).valid?
      unprocessable_entity "objects/new"
    end

    object.save

    env.created edit_object_path(object)
  end

  get "/objects/:id" do |env|
    unless (object = get_object(env, iri_param))
      not_found
    end

    redirect edit_object_path if object.draft?

    ok "objects/object"
  end

  get "/objects/:id/thread" do |env|
    unless (object = get_object(env, iri_param))
      not_found
    end

    redirect edit_object_path if object.draft?

    thread = object.thread(approved_by: object.attributed_to)

    ok "objects/thread"
  end

  get "/objects/:id/edit" do |env|
    unless (object = get_editable(env, iri_param))
      not_found
    end

    ok "objects/edit"
  end

  post "/objects/:id" do |env|
    unless (object = get_editable(env, iri_param)) && object.draft?
      not_found
    end

    unless object.assign(params(env)).valid?
      unprocessable_entity "objects/edit"
    end

    object.save

    redirect object_path(object)
  end

  delete "/objects/:id" do |env|
    unless (object = get_editable(env, iri_param)) && object.draft?
      not_found
    end

    object.delete

    redirect back_path
  end

  get "/remote/objects/:id" do |env|
    unless (object = get_object(env, id_param))
      not_found
    end

    ok "objects/object"
  end

  get "/remote/objects/:id/thread" do |env|
    unless (object = get_object(env, id_param))
      not_found
    end

    thread = object.thread

    ok "objects/thread"
  end

  get "/remote/objects/:id/replies" do |env|
    id = env.params.url["id"].to_i64

    unless (object = get_object(env, id))
      not_found
    end

    ok "objects/reply"
  end

  post "/remote/objects/:id/approve" do |env|
    actor = env.account.actor

    not_found unless (object = ActivityPub::Object.find?(id_param))
    not_found unless actor.in_inbox?(object) || actor.in_outbox?(object)

    redirect back_path if actor.approve(object)

    bad_request
  end

  post "/remote/objects/:id/unapprove" do |env|
    actor = env.account.actor

    not_found unless (object = ActivityPub::Object.find?(id_param))
    not_found unless actor.in_inbox?(object) || actor.in_outbox?(object)

    redirect back_path if actor.unapprove(object)

    bad_request
  end

  private def self.params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    {
      "source" => params["content"]?.try(&.as(String).presence).try { |content| ActivityPub::Object::Source.new(content, "text/html; editor=trix") },
      "canonical_path" => params["canonical_path"]?.try(&.as(String).presence)
    }
  end

  private def self.get_editable(env, iri_or_id)
    if (object = ActivityPub::Object.find?(iri_or_id))
      if env.account.actor == object.attributed_to?
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
