require "../framework/controller"
require "../models/tag/hashtag"
require "../models/relationship/content/follow/hashtag"
require "../models/task/fetch/hashtag"

class TagsController
  include Ktistec::Controller

  skip_auth ["/tags/:hashtag"], GET

  get "/tags/:hashtag" do |env|
    hashtag = env.params.url["hashtag"]

    if env.account?
      collection = Tag::Hashtag.all_objects(hashtag, **pagination_params(env))
      count = Tag::Hashtag.all_objects_count(hashtag)
    else
      collection = Tag::Hashtag.public_posts(hashtag, **pagination_params(env))
      count = Tag::Hashtag.public_posts_count(hashtag)
    end

    not_found if collection.empty?

    if env.account?
      follow = Relationship::Content::Follow::Hashtag.find?(actor: env.account.actor, name: hashtag)
      task = Task::Fetch::Hashtag.find?(source: env.account.actor, name: hashtag)
    end

    ok "tags/index", env: env, hashtag: hashtag, collection: collection, count: count, follow: follow, task: task
  end

  private macro set_up
    hashtag = env.params.url["hashtag"]
    follow = nil
    task = nil
  end

  private macro check_collection
    count = Tag::Hashtag.all_objects_count(hashtag)
    collection = Tag::Hashtag.all_objects(hashtag)
    not_found if collection.empty?
  end

  private macro find_or_new_follow
    follow = Relationship::Content::Follow::Hashtag.find_or_new(actor: env.account.actor, name: hashtag)
    follow.save if follow.new_record?
  end

  private macro find_or_new_task
    task = Task::Fetch::Hashtag.find_or_new(source: env.account.actor, name: hashtag)
    task.assign(backtrace: nil).schedule if task.runnable? || task.complete
  end

  private macro destroy_follow
    follow = Relationship::Content::Follow::Hashtag.find?(actor: env.account.actor, name: hashtag)
    follow.destroy if follow
  end

  private macro complete_task
    task = Task::Fetch::Hashtag.find?(source: env.account.actor, name: hashtag)
    task.complete! if task
  end

  private macro render_or_redirect
    if in_turbo_frame?
      ok "tags/index", env: env, hashtag: hashtag, collection: collection, count: count, follow: follow, task: task
    else
      redirect back_path
    end
  end

  post "/tags/:hashtag/follow" do |env|
    set_up
    check_collection
    find_or_new_follow
    find_or_new_task
    render_or_redirect
  end

  post "/tags/:hashtag/unfollow" do |env|
    set_up
    check_collection
    destroy_follow
    complete_task
    render_or_redirect
  end

  post "/tags/:hashtag/fetch/start" do |env|
    set_up
    check_collection
    find_or_new_task
    render_or_redirect
  end

  post "/tags/:hashtag/fetch/cancel" do |env|
    set_up
    check_collection
    complete_task
    render_or_redirect
  end
end
