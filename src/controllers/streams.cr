require "../framework/controller"
require "../framework/topic"

require "../models/relationship/content/follow/hashtag"
require "../models/task/fetch/hashtag"

class StreamsController
  include Ktistec::Controller

  macro stop
    raise Ktistec::Topic::Stop.new
  end

  get "/stream/tags/:hashtag" do |env|
    hashtag = env.params.url["hashtag"]
    if (first_count = Tag::Hashtag.all_objects_count(hashtag)) < 1
      not_found
    end
    setup_response(env.response)
    Ktistec::Topic{hashtag_path(hashtag)}.subscribe do
      task = Task::Fetch::Hashtag.find(source: env.account.actor, name: hashtag)
      follow = Relationship::Content::Follow::Hashtag.find(actor: env.account.actor, name: hashtag)
      count = Tag::Hashtag.all_objects_count(hashtag)
      body = tag_page_tag_controls(env, hashtag, task, follow, count)
      stream_replace(env.response, id: "tag_page_tag_controls", body: body)
      if count > first_count
        first_count = Int64::MAX
        body = refresh_posts_message(hashtag_path(hashtag))
        stream_replace(env.response, selector: "section.ui.feed > .refresh_posts_placeholder", body: body)
      end
    rescue HTTP::Server::ClientError
      stop
    end
  end

  get "/stream/objects/:id/thread" do |env|
    id = env.params.url["id"].to_i
    unless (object = ActivityPub::Object.find?(id))
      not_found
    end
    thread = object.thread(for_actor: env.account.actor)
    first_count = thread.size
    setup_response(env.response)
    Ktistec::Topic{thread.first.thread.not_nil!}.subscribe do
      thread = object.thread(for_actor: env.account.actor)
      count = thread.size
      task = Task::Fetch::Thread.find?(source: env.account.actor, thread: thread.first.thread)
      follow = Relationship::Content::Follow::Thread.find?(actor: env.account.actor, thread: thread.first.thread)
      body = thread_page_thread_controls(env, thread, task, follow)
      stream_replace(env.response, id: "thread_page_thread_controls", body: body)
      if count > first_count
        first_count = Int64::MAX
        body = refresh_posts_message(remote_thread_path(object))
        stream_replace(env.response, selector: "section.ui.feed > .refresh_posts_placeholder", body: body)
      end
    rescue HTTP::Server::ClientError
      stop
    end
  end

  get "/stream/actor/timeline" do |env|
    since = Time.utc
    first_count = timeline_count(env, since)
    setup_response(env.response)
    Ktistec::Topic{"#{actor_path(env.account.actor)}/timeline"}.subscribe do
      count = timeline_count(env, since)
      if count > first_count
        first_count = Int64::MAX
        query = env.request.query.try { |query| "?#{query}" } || ""
        body = refresh_posts_message("#{actor_path(env.account.actor)}#{query}")
        stream_replace(env.response, selector: "section.ui.feed > .refresh_posts_placeholder", body: body)
      else
        stream_no_op(env.response)
      end
    rescue HTTP::Server::ClientError
      stop
    end
  end

  private def self.timeline_count(env, since)
    filters = env.params.query.fetch_all("filters")
    actor = env.account.actor
    if filters.includes?("no-shares") && filters.includes?("no-replies")
      timeline = actor.timeline(since: since, inclusion: [Relationship::Content::Timeline::Create], exclude_replies: true)
    elsif filters.includes?("no-shares")
      timeline = actor.timeline(since: since, inclusion: [Relationship::Content::Timeline::Create])
    elsif filters.includes?("no-replies")
      timeline = actor.timeline(since: since, exclude_replies: true)
    else
      timeline = actor.timeline(since: since)
    end
  end

  get "/stream/everything" do |env|
    setup_response(env.response)
    Ktistec::Topic{everything_path}.subscribe do
      stream_refresh(env.response)
    rescue HTTP::Server::ClientError
      stop
    end
  end

  def self.setup_response(response : HTTP::Server::Response)
    response.content_type = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"
    response.puts
    response.flush
  end

  # Sends a no-op action.
  #
  def self.stream_no_op(io)
    stream_action(io, nil, "no-op", nil, nil)
  end

  {% for action in %w(append prepend replace update remove before after morph refresh) %}
    def self.stream_{{action.id}}(io, body = nil, id = nil, selector = nil)
      stream_action(io, body, {{action}}, id, selector)
    end
  {% end %}

  def self.stream_action(io : IO, body : String?, action : String, id : String?, selector : String?)
    if id && !selector
      io.puts %Q|data: <turbo-stream action="#{action}" target="#{id}">|
    elsif selector && !id
      io.puts %Q|data: <turbo-stream action="#{action}" targets="#{selector}">|
    else
      io.puts %Q|data: <turbo-stream action="#{action}">|
    end
    if body
      io.puts "data: <template>"
      body.each_line do |line|
        io.puts "data: #{line}"
      end
      io.puts "data: </template>"
    end
    io.puts "data: </turbo-stream>"
    io.puts
    io.flush
  end
end

module ActivityPub
  class Object
    def after_create
      Ktistec::Topic{Ktistec::ViewHelper.everything_path}.notify_subscribers
    end

    # updates the `subject` based on the `thread` when an object is
    # saved.

    def after_save
      previous_def
      Ktistec::Topic.rename_subject(self.iri, self.thread)
    end
  end
end
