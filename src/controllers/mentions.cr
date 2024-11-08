require "../framework/controller"
require "../models/tag/mention"
require "../models/relationship/content/follow/mention"

class MentionsController
  include Ktistec::Controller

  get "/mentions/:mention" do |env|
    mention = env.params.url["mention"]

    collection = Tag::Mention.all_objects(mention, **pagination_params(env))
    count = Tag::Mention.all_objects_count(mention)

    not_found if collection.empty?

    follow = Relationship::Content::Follow::Mention.find?(actor: env.account.actor, name: mention)

    ok "mentions/index", env: env, mention: mention, collection: collection, count: count, follow: follow
  end

  post "/mentions/:mention/follow" do |env|
    mention = env.params.url["mention"]

    collection = Tag::Mention.all_objects(mention)
    count = Tag::Mention.all_objects_count(mention)

    not_found if collection.empty?

    follow = Relationship::Content::Follow::Mention.find_or_new(actor: env.account.actor, name: mention)
    follow.save if follow.new_record?

    if in_turbo_frame?
      ok "mentions/index", env: env, mention: mention, collection: collection, count: count, follow: follow
    else
      redirect back_path
    end
  end

  post "/mentions/:mention/unfollow" do |env|
    mention = env.params.url["mention"]

    collection = Tag::Mention.all_objects(mention)
    count = Tag::Mention.all_objects_count(mention)

    not_found if collection.empty?

    follow = Relationship::Content::Follow::Mention.find?(actor: env.account.actor, name: mention)
    follow.destroy if follow

    if in_turbo_frame?
      ok "mentions/index", env: env, mention: mention, collection: collection, count: count, follow: nil
    else
      redirect back_path
    end
  end
end
