require "../framework/controller"
require "../models/activity_pub/object/note"
require "../models/relationship/content/follow/thread"
require "../models/task/fetch/thread"

class ObjectsController
  include Ktistec::Controller

  skip_auth ["/objects/:id", "/objects/:id/replies", "/objects/:id/thread"], GET

  post "/objects" do |env|
    object = ActivityPub::Object::Note.new(
      iri: "#{host}/objects/#{id}",
      attributed_to: env.account.actor
    )

    unless object.assign(params(env)).valid?
      unprocessable_entity "objects/new", env: env, object: object, recursive: false
    end

    object.save

    env.created edit_object_path(object)
  end

  get "/objects/:id" do |env|
    unless (object = get_object(env, iri_param(env)))
      not_found
    end

    redirect edit_object_path if object.draft?

    ok "objects/object", env: env, object: object, recursive: false
  end

  get "/objects/:id/replies" do |env|
    unless (object = get_object(env, iri_param(env, "/objects")))
      not_found
    end

    redirect edit_object_path if object.draft?

    replies = object.replies(for_actor: object.attributed_to)

    ok "objects/replies", env: env, object: object, replies: replies, recursive: false
  end

  get "/objects/:id/thread" do |env|
    unless (object = get_object(env, iri_param(env, "/objects")))
      not_found
    end

    redirect edit_object_path if object.draft?

    thread = object.thread(approved_by: object.attributed_to)

    ok "objects/thread", env: env, object: object, thread: thread, follow: nil, task: nil
  end

  get "/objects/:id/edit" do |env|
    unless (object = get_editable(env, iri_param(env, "/objects")))
      not_found
    end

    ok "objects/edit", env: env, object: object, recursive: false
  end

  post "/objects/:id" do |env|
    unless (object = get_editable(env, iri_param(env))) && object.draft?
      not_found
    end

    unless object.assign(params(env)).valid?
      unprocessable_entity "objects/edit", env: env, object: object, recursive: false
    end

    object.save

    redirect object_path(object)
  end

  delete "/objects/:id" do |env|
    unless (object = get_editable(env, iri_param(env))) && object.draft?
      not_found
    end

    object.delete!

    redirect back_path
  end

  get "/remote/objects/:id" do |env|
    unless (object = get_remote_object(env, id_param(env)))
      not_found
    end

    ok "objects/object", env: env, object: object, recursive: false
  end

  get "/remote/objects/:id/thread" do |env|
    unless (object = get_remote_object(env, id_param(env)))
      not_found
    end

    thread = object.thread(for_actor: env.account.actor)

    follow = Relationship::Content::Follow::Thread.find?(actor: env.account.actor, thread: thread.first.thread)

    task = Task::Fetch::Thread.find?(source: env.account.actor, thread: thread.first.thread)

    ok "objects/thread", env: env, object: object, thread: thread, follow: follow, task: task
  end

  get "/remote/objects/:id/reply" do |env|
    unless (object = get_remote_object(env, id_param(env)))
      not_found
    end

    ok "objects/reply", env: env, object: object
  end

  post "/remote/objects/:id/approve" do |env|
    actor = env.account.actor

    not_found unless (object = ActivityPub::Object.find?(id_param(env)))

    redirect back_path if actor.approve(object)

    bad_request
  end

  post "/remote/objects/:id/unapprove" do |env|
    actor = env.account.actor

    not_found unless (object = ActivityPub::Object.find?(id_param(env)))

    redirect back_path if actor.unapprove(object)

    bad_request
  end

  post "/remote/objects/:id/block" do |env|
    not_found unless (object = ActivityPub::Object.find?(id_param(env)))

    object.block!

    redirect back_path
  end

  post "/remote/objects/:id/unblock" do |env|
    not_found unless (object = ActivityPub::Object.find?(id_param(env)))

    object.unblock!

    redirect back_path
  end

  # NOTE: there is currently no standard property whose value
  # indicates that an object participates in a thread. mastodon uses
  # the `conversation` property. friendica uses `context`. others use
  # neither. in our implementation, following any object in a thread
  # follows the thread, which is indicated by a shared `thread`
  # property, which identifies the root of the thread and which is
  # updated when previously uncached parent objects are fetched.

  post "/remote/objects/:id/follow" do |env|
    unless (object = ActivityPub::Object.find?(id_param(env))) && !object.draft?
      not_found
    end

    thread = object.thread(for_actor: env.account.actor)

    thread.first.save # lazy migration -- ensure the `thread` property is up to date

    follow = Relationship::Content::Follow::Thread.find_or_new(actor: env.account.actor, thread: thread.first.thread)
    follow.save if follow.new_record?

    task = Task::Fetch::Thread.find_or_new(source: env.account.actor, thread: thread.first.thread)
    task.assign(backtrace: nil).schedule if task.runnable? || task.complete

    if turbo_frame?
      ok "objects/thread", env: env, object: object, thread: thread, follow: follow, task: task
    else
      redirect back_path
    end
  end

  post "/remote/objects/:id/unfollow" do |env|
    unless (object = ActivityPub::Object.find?(id_param(env))) && !object.draft?
      not_found
    end

    thread = object.thread(for_actor: env.account.actor)

    follow = Relationship::Content::Follow::Thread.find?(actor: env.account.actor, thread: thread.first.thread)
    follow.destroy if follow

    task = Task::Fetch::Thread.find?(source: env.account.actor, thread: thread.first.thread)
    task.complete! if task

    if turbo_frame?
      ok "objects/thread", env: env, object: object, thread: thread, follow: follow, task: task
    else
      redirect back_path
    end
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
      if (object.visible && !object.draft?) ||
         ((account = env.account?) &&
          (account.actor == object.attributed_to? || account.actor.in_inbox?(object)))
        object
      end
    end
  end

  private def self.get_remote_object(env, iri_or_id)
    if (object = ActivityPub::Object.find?(iri_or_id))
      if (object.visible && !object.draft?) ||
         ((account = env.account?) &&
          ((account.actor == object.attributed_to? && !object.draft?) || account.actor.in_inbox?(object)))
        object
      end
    end
  end

  private def self.get_account(env)
    Account.find?(username: env.params.url["username"]?)
  end
end
