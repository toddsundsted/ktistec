require "../framework/controller"
require "../models/activity_pub/object/note"
require "../models/relationship/content/bookmark"
require "../models/relationship/content/pin"
require "../models/relationship/content/follow/thread"
require "../models/task/fetch/thread"
require "../models/translation"

class ObjectsController
  include Ktistec::Controller

  skip_auth ["/objects/:id", "/objects/:id/replies", "/objects/:id/thread"], GET

  # Authorizes object access.
  #
  # Returns the object if the user is authorized to view it, `nil`
  # otherwise.
  #
  private def self.get_object(env, iri_or_id)
    if (object = ActivityPub::Object.find?(iri_or_id, include_deleted: true))
      if (object.visible && !object.draft?) ||
         ((account = env.account?) &&
          (account.actor == object.attributed_to? || account.actor.in_inbox?(object)))
        object
      end
    end
  end

  # Authorizes object access for editing.
  #
  # Returns the object if the user is authorized to edit it, `nil`
  # otherwise.
  #
  private def self.get_object_editable(env, iri_or_id)
    if (object = ActivityPub::Object.find?(iri_or_id))
      if (account = env.account?) && account.actor == object.attributed_to?
        object
      end
    end
  end

  # Authorizes object for approval/unapproval.
  #
  # Returns the object if the user is authorized to approve/unapprove
  # it, `nil` otherwise.
  #
  private def self.get_object_approvable(env, iri_or_id)
    if (object = ActivityPub::Object.find?(iri_or_id)) && object.in_reply_to?
      if (account = env.account?)
        thread = object.thread(for_actor: account.actor)
        if thread.first.attributed_to? == account.actor
          object
        end
      end
    end
  end

  post "/objects" do |env|
    object = ActivityPub::Object::Note.new(
      iri: "#{host}/objects/#{id}",
      attributed_to: env.account.actor
    )

    unless object.assign(params(env)).valid?
      if accepts_turbo_stream?
        unprocessable_entity "partials/editor", env: env, object: object, _operation: "replace", _method: "morph", _target: "object-new"
      else
        unprocessable_entity "objects/new", env: env, object: object, recursive: false
      end
    end

    object.save

    if accepts?("application/ld+json", "application/activity+json", "application/json")
      created object_path(object), "objects/object", env: env, object: object, recursive: false
    elsif accepts_turbo_stream?
      ok "partials/editor", env: env, object: object, _operation: "replace", _method: "morph", _target: "object-new"
    else
      redirect edit_object_path(object)
    end
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

    replies = env.account? ?
      object.replies(for_actor: env.account.actor) :
      object.replies(approved_by: object.attributed_to)

    ok "objects/replies", env: env, object: object, replies: replies, recursive: false
  end

  get "/objects/:id/thread" do |env|
    unless (object = get_object(env, iri_param(env, "/objects")))
      not_found
    end

    redirect edit_object_path if object.draft?

    thread = env.account? ?
      object.thread(for_actor: env.account.actor) :
      object.thread(approved_by: object.attributed_to)

    ok "objects/thread", env: env, object: object, thread: thread, follow: nil, task: nil
  end

  get "/objects/:id/edit" do |env|
    unless (object = get_object_editable(env, iri_param(env, "/objects")))
      not_found
    end

    ok "objects/edit", env: env, object: object, recursive: false
  end

  post "/objects/:id" do |env|
    unless (object = get_object_editable(env, iri_param(env))) && object.draft?
      not_found
    end

    unless object.assign(params(env)).valid?
      if accepts_turbo_stream?
        unprocessable_entity "partials/editor", env: env, object: object, _operation: "replace", _method: "morph", _target: "object-#{object.id}"
      else
        unprocessable_entity "objects/edit", env: env, object: object, recursive: false
      end
    end

    object.save

    if accepts?("application/ld+json", "application/activity+json", "application/json")
      ok "objects/object", env: env, object: object, recursive: false
    elsif accepts_turbo_stream?
      ok "partials/editor", env: env, object: object, _operation: "replace", _method: "morph", _target: "object-#{object.id}"
    else
      redirect edit_object_path(object)
    end
  end

  delete "/objects/:id" do |env|
    unless (object = get_object_editable(env, iri_param(env))) && object.draft?
      not_found
    end

    object.destroy

    redirect back_path
  end

  get "/remote/objects/:id" do |env|
    unless (object = get_object(env, id_param(env)))
      not_found
    end

    ok "objects/object", env: env, object: object, recursive: false
  end

  get "/remote/objects/:id/thread" do |env|
    unless (object = get_object(env, id_param(env))) && !object.draft?
      not_found
    end

    thread = object.thread(for_actor: env.account.actor)

    follow = Relationship::Content::Follow::Thread.find?(actor: env.account.actor, thread: thread.first.thread)

    task = Task::Fetch::Thread.find?(source: env.account.actor, thread: thread.first.thread)

    ok "objects/thread", env: env, object: object, thread: thread, follow: follow, task: task
  end

  get "/remote/objects/:id/thread/analysis" do |env|
    unless (object = get_object(env, id_param(env))) && !object.draft?
      not_found
    end

    analysis = object.analyze_thread(for_actor: env.account.actor)

    ok "partials/thread_analysis", env: env, object: object, analysis: analysis
  end

  get "/remote/objects/:id/branch" do |env|
    unless (object = get_object(env, id_param(env))) && !object.draft?
      not_found
    end

    thread = object.descendants

    ok "objects/branch", env: env, object: object, thread: thread
  end

  get "/remote/objects/:id/reply" do |env|
    unless (object = get_object(env, id_param(env))) && !object.draft?
      not_found
    end

    ok "objects/reply", env: env, object: object
  end

  post "/remote/objects/:id/approve" do |env|
    actor = env.account.actor

    not_found unless (object = get_object_approvable(env, id_param(env)))

    redirect back_path if actor.approve(object)

    bad_request
  end

  post "/remote/objects/:id/unapprove" do |env|
    actor = env.account.actor

    not_found unless (object = get_object_approvable(env, id_param(env)))

    redirect back_path if actor.unapprove(object)

    bad_request
  end

  # MULTI_USER NOTE: block and unoperations set/clear a global
  # `blocked_at` timestamp that hides the object from ALL users. this
  # is a single-user design remnant. proper multi-user support would
  # require per-user blocking relationships.

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

  private macro set_up
    follow = nil
    task = nil
  end

  private macro check_thread
    unless (object = get_object(env, id_param(env))) && !object.draft?
      not_found
    end
    thread = object.thread(for_actor: env.account.actor)
    # lazily migrate objects and ensure the `thread` property is set
    thread.first.thread!
  end

  private macro find_or_new_follow
    follow = Relationship::Content::Follow::Thread.find_or_new(actor: env.account.actor, thread: thread.first.thread)
    follow.save if follow.new_record?
  end

  private macro find_or_new_task
    task = Task::Fetch::Thread.find_or_new(source: env.account.actor, thread: thread.first.thread)
    task.assign(backtrace: nil).schedule if task.runnable? || task.complete
  end

  private macro destroy_follow
    follow = Relationship::Content::Follow::Thread.find?(actor: env.account.actor, thread: thread.first.thread)
    follow.destroy if follow
  end

  private macro complete_task
    task = Task::Fetch::Thread.find?(source: env.account.actor, thread: thread.first.thread)
    task.complete! if task
  end

  private macro render_or_redirect
    if in_turbo_frame?
      ok "objects/thread", env: env, object: object, thread: thread, follow: follow, task: task
    else
      redirect back_path
    end
  end

  post "/remote/objects/:id/follow" do |env|
    set_up
    check_thread
    find_or_new_follow
    find_or_new_task
    render_or_redirect
  end

  post "/remote/objects/:id/unfollow" do |env|
    set_up
    check_thread
    destroy_follow
    complete_task
    render_or_redirect
  end

  post "/remote/objects/:id/bookmark" do |env|
    not_found unless (object = get_object(env, id_param(env))) && !object.draft?

    bookmark = Relationship::Content::Bookmark.find_or_new(actor: env.account.actor, object: object)
    bookmark.save if bookmark.new_record?

    if accepts_turbo_stream?
      turbo_stream_refresh
    else
      redirect back_path
    end
  end

  delete "/remote/objects/:id/bookmark" do |env|
    not_found unless (object = get_object(env, id_param(env))) && !object.draft?

    bookmark = Relationship::Content::Bookmark.find?(actor: env.account.actor, object: object)
    bookmark.destroy if bookmark

    if accepts_turbo_stream?
      turbo_stream_refresh
    else
      redirect back_path
    end
  end

  post "/remote/objects/:id/pin" do |env|
    not_found unless (object = get_object(env, id_param(env))) && !object.draft?
    forbidden unless object.attributed_to == env.account.actor

    pin = Relationship::Content::Pin.find_or_new(actor: env.account.actor, object: object)
    pin.save if pin.new_record?

    if accepts_turbo_stream?
      turbo_stream_refresh
    else
      redirect back_path
    end
  end

  delete "/remote/objects/:id/pin" do |env|
    not_found unless (object = get_object(env, id_param(env))) && !object.draft?
    forbidden unless object.attributed_to == env.account.actor

    pin = Relationship::Content::Pin.find?(actor: env.account.actor, object: object)
    pin.destroy if pin

    if accepts_turbo_stream?
      turbo_stream_refresh
    else
      redirect back_path
    end
  end

  post "/remote/objects/:id/fetch/start" do |env|
    set_up
    check_thread
    find_or_new_task
    render_or_redirect
  end

  post "/remote/objects/:id/fetch/cancel" do |env|
    set_up
    check_thread
    complete_task
    render_or_redirect
  end

  # MULTI_USER NOTE: translations are global (shared by all
  # users). this is a single-user remnant and known limitation -
  # proper multi-user support would permit per-user translations.

  post "/remote/objects/:id/translation/create" do |env|
    not_found unless (object = get_object(env, id_param(env)))

    object.translations.each(&.destroy)

    if (translator = Ktistec.translator)
      if (source = object.language) && (target = env.account.language)
        if source.split("-").first != target.split("-").first
          begin
            translations = translator.translate(object.name, object.summary, object.content, source, target)
            Translation.new(
              origin: object,
              name: translations[:name],
              summary: translations[:summary],
              content: translations[:content],
            ).save
          rescue ex : KeyError
            # ignore
          end
        end
      end
    end

    redirect back_path
  end

  post "/remote/objects/:id/translation/clear" do |env|
    not_found unless (object = get_object(env, id_param(env)))

    object.translations.each(&.destroy)

    redirect back_path
  end

  private def self.params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    visible, to, cc = addressing(params, env.account.actor)
    media_type = params["media-type"]?.try(&.as(String).presence) || "text/html; editor=trix"
    {
      "source" => params["content"]?.try(&.as(String).presence).try { |content| ActivityPub::Object::Source.new(content, media_type) },
      "visible" => visible,
      "to" => to.to_a,
      "cc" => cc.to_a,
      "language" => params["language"]?.try(&.as(String).presence),
      "name" => params["name"]?.try(&.as(String).presence),
      "summary" => params["summary"]?.try(&.as(String).presence),
      "sensitive" => params["sensitive"]?.try(&.as(String)) == "true",
      "canonical_path" => params["canonical-path"]?.try(&.as(String).presence),
      "in_reply_to_iri" => params["in-reply-to"]?.try(&.as(String).presence),
    }.compact
  end
end
