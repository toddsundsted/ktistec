require "../framework/controller"
require "../framework/topic"

require "../models/relationship/content/follow/hashtag"
require "../models/task/fetch/hashtag"

class StreamsController
  include Ktistec::Controller

  Log = ::Log.for("streaming")

  macro stop
    raise Ktistec::Topic::Stop.new
  end

  ## Turbo Stream Action helpers

  # Renders action to replace the actor icon.
  #
  def self.replace_actor_icon(io, id)
    actor = ActivityPub::Actor.find(id)
    # omit "data-actor-id" so that replacement can only be attempted once
    body = %Q|<img src="#{actor.icon}">|
    stream_replace(io, selector: ":is(i,img)[data-actor-id='#{actor.id}']", body: body)
  end

  # Renders action to replace the notifications count.
  #
  def self.replace_notifications_count(io, account)
    body = render "src/views/partials/notifications-count.html.slang"
    stream_replace(io, selector: ".ui.menu > .item.notifications", body: body)
  end

  # Renders action to replace the refresh posts message.
  #
  def self.replace_refresh_posts_message(io, id = false, path = "")
    body = render "src/views/partials/refresh-posts.html.slang"
    stream_replace(io, target: "refresh-posts-message", body: body, id: id)
  end

  # Limits the number of long-lived connections.
  #
  # Limits the number of long-lived connections by maintaining a pool
  # of connections. When the pool is full, adding a new connection
  # closes the oldest connection.
  #
  # A "connection" is any subclass of `IO`.
  #
  class ConnectionPool
    def initialize(capacity)
      @connections = Array(IO?).new(capacity, nil)
      @index = 0
    end

    # Returns the capacity of the pool.
    #
    def capacity
      @connections.size
    end

    # Returns the number of connections in the pool.
    #
    def size
      @connections.count(&.nil?.!)
    end

    # Pushes `connection` into the pool.
    #
    # If the pool is at capacity, the oldest connection is closed,
    # removed from the pool, and returned.
    #
    def push(connection)
      index = @index % @connections.size
      last, @connections[index] = @connections[index], connection
      @index += 1
      last.close unless last.nil? || last.closed?
      last
    end

    # Returns `true` if the pool includes `connection`.
    #
    def includes?(connection)
      @connections.includes?(connection)
    end
  end

  # ensure there are no more than five long-lived connections handling
  # subscriptions "per browser", which is here implemented as "per
  # session". this helps limit blocking and ensures that ktistec never
  # runs out of file descriptors/sockets (we hit 1024 simultaneous
  # connections once, while testing at epiktistes.com -- poor thing
  # couldn't even connect to the database).

  @@sessions_pools = Hash(Session, ConnectionPool).new { |h, k| h[k] = ConnectionPool.new(5) }

  private macro subscribe(*subjects, &block)
    Ktistec::Topic{{{subjects.splat}}}.tap do |topic|
      @@sessions_pools[env.session].push(env.response.@io)
      topic.subscribe(timeout: 1.minute) do |{{block.args.join(",").id}}|
        if {{block.args.join(" && ").id}}
          {{block.body}}
        else # timeout
          stream_no_op(env.response)
        end
      rescue HTTP::Server::ClientError | IO::Error
        stop
      end
    end
  end

  get "/stream/mentions/:mention" do |env|
    mention = env.params.url["mention"]
    if Tag::Mention.all_objects_count(mention) < 1
      not_found
    end
    setup_response(env.response)
    subscribe "/actor/refresh", mention_path(mention) do |subject, value|
      case subject
      when "/actor/refresh"
        if (id = value.to_i64?)
          replace_actor_icon(env.response, id)
        end
      else
        follow = Relationship::Content::Follow::Mention.find?(actor: env.account.actor, name: mention)
        count = Tag::Mention.all_objects_count(mention)
        body = mention_page_mention_banner(env, mention, follow, count)
        stream_replace(env.response, target: "mention_page_mention_banner", body: body)
        unless value.blank?
          replace_refresh_posts_message(env.response)
        end
      end
    end
  end

  get "/stream/tags/:hashtag" do |env|
    hashtag = env.params.url["hashtag"]
    if Tag::Hashtag.all_objects_count(hashtag) < 1
      not_found
    end
    setup_response(env.response)
    subscribe "/actor/refresh", hashtag_path(hashtag) do |subject, value|
      case subject
      when "/actor/refresh"
        if (id = value.to_i64?)
          replace_actor_icon(env.response, id)
        end
      else
        task = Task::Fetch::Hashtag.find?(source: env.account.actor, name: hashtag)
        follow = Relationship::Content::Follow::Hashtag.find?(actor: env.account.actor, name: hashtag)
        count = Tag::Hashtag.all_objects_count(hashtag)
        body = tag_page_tag_controls(env, hashtag, task, follow, count)
        stream_replace(env.response, target: "tag_page_tag_controls", body: body)
        unless value.blank?
          replace_refresh_posts_message(env.response)
        end
      end
    end
  end

  get "/stream/objects/:id/thread" do |env|
    id = env.params.url["id"].to_i
    unless (object = ActivityPub::Object.find?(id))
      not_found
    end
    setup_response(env.response)
    subscribe "/actor/refresh", object.thread.not_nil! do |subject, value|
      case subject
      when "/actor/refresh"
        if (id = value.to_i64?)
          replace_actor_icon(env.response, id)
        end
      else
        thread = object.thread(for_actor: env.account.actor)
        count = thread.size
        task = Task::Fetch::Thread.find?(source: env.account.actor, thread: thread.first.thread)
        follow = Relationship::Content::Follow::Thread.find?(actor: env.account.actor, thread: thread.first.thread)
        body = thread_page_thread_controls(env, thread, task, follow)
        stream_replace(env.response, target: "thread_page_thread_controls", body: body)
        unless value.blank?
          replace_refresh_posts_message(env.response)
        end
      end
    end
  end

  get "/stream/actor/homepage" do |env|
    setup_response(env.response)
    if env.request.headers["Last-Event-ID"]? =~ /^(\d+):(\d+)$/ && (seconds = $1.to_i?) && (count = $2.to_i?)
      since = Time.unix(seconds)
      first_count = count
      if (count = timeline_count(env, since)) > first_count
        Log.trace { "header - since: #{since} first_count: #{first_count} count: #{count}" }
        first_count = count
        id = "#{since.to_unix}:#{first_count}"
        replace_refresh_posts_message(env.response, id)
      else
        Log.trace { "header - since: #{since} first_count: #{first_count}" }
      end
    else
      since = Time.utc
      first_count = timeline_count(env, since)
      Log.trace { "initial - since: #{since} first_count: #{first_count}" }
      id = "#{since.to_unix}:#{first_count}"
      stream_no_op(env.response, id)
    end
    subscribe "/actor/refresh", "#{actor_path(env.account.actor)}/notifications", "#{actor_path(env.account.actor)}/timeline" do |subject, value|
      case subject
      when "/actor/refresh"
        if (id = value.to_i64?)
          replace_actor_icon(env.response, id)
        end
      when "#{actor_path(env.account.actor)}/notifications"
        replace_notifications_count(env.response,  env.account)
      when "#{actor_path(env.account.actor)}/timeline"
        if (count = timeline_count(env, since)) > first_count
          Log.trace { "next - since: #{since} first_count: #{first_count} count: #{count}" }
          first_count = count
          id = "#{since.to_unix}:#{first_count}"
          replace_refresh_posts_message(env.response, id)
        end
      end
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
    subscribe "/actor/refresh", everything_path do |subject, value|
      case subject
      when "/actor/refresh"
        if (id = value.to_i64?)
          replace_actor_icon(env.response, id)
        end
      else
        stream_refresh(env.response)
      end
    end
  end

  def self.setup_response(response : HTTP::Server::Response)
    response.content_type = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"
    # call `upgrade` to write the headers to the output
    response.upgrade {}
    response.flush
  end

  # Sends a no-op action.
  #
  def self.stream_no_op(io, id = false)
    stream_action(io, nil, "no-op", nil, nil, id)
  end

  {% for action in %w(append prepend replace update remove before after morph refresh) %}
    def self.stream_{{action.id}}(io, body = nil, target = nil, selector = nil, id = false)
      stream_action(io, body, {{action}}, target, selector, id)
    end
  {% end %}

  def self.stream_action(io : IO, body : String?, action : String, target : String?, selector : String?, id : String | Bool | Nil = false)
    if target && !selector
      io.puts %Q|data: <turbo-stream action="#{action}" target="#{target}">|
    elsif selector && !target
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
    if id.nil?
      io.puts "id"
    elsif id.is_a?(String)
      io.puts "id: #{id}"
    end
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
