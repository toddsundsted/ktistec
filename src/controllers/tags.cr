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
      count = Tag::Hashtag.count_all_objects(hashtag)
    else
      collection = Tag::Hashtag.public_objects(hashtag, **pagination_params(env))
      count = Tag::Hashtag.count_public_objects(hashtag)
    end

    not_found if collection.empty?

    if env.account?
      follow = Relationship::Content::Follow::Hashtag.find?(actor: env.account.actor, name: hashtag)
      task = Task::Fetch::Hashtag.find?(source: env.account.actor, name: hashtag)
    end

    ok "tags/index"
  end

  post "/tags/:hashtag/follow" do |env|
    hashtag = env.params.url["hashtag"]

    collection = Tag::Hashtag.all_objects(hashtag)
    count = Tag::Hashtag.count_all_objects(hashtag)

    not_found if collection.empty?

    follow = Relationship::Content::Follow::Hashtag.find_or_new(actor: env.account.actor, name: hashtag)
    follow.save if follow.new_record?

    task = Task::Fetch::Hashtag.find_or_new(source: env.account.actor, name: hashtag)
    task.schedule if task.runnable? || task.complete

    if turbo_frame?
      ok "tags/index"
    else
      redirect back_path
    end
  end

  post "/tags/:hashtag/unfollow" do |env|
    hashtag = env.params.url["hashtag"]

    collection = Tag::Hashtag.all_objects(hashtag)
    count = Tag::Hashtag.count_all_objects(hashtag)

    not_found if collection.empty?

    follow = Relationship::Content::Follow::Hashtag.find?(actor: env.account.actor, name: hashtag)
    follow.destroy if follow

    task = Task::Fetch::Hashtag.find?(source: env.account.actor, name: hashtag)
    task.complete! if task

    if turbo_frame?
      ok "tags/index"
    else
      redirect back_path
    end
  end
end
