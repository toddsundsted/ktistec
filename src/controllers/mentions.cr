require "../framework/controller"
require "../models/tag/mention"
require "../models/relationship/content/follow/mention"

class MentionsController
  include Ktistec::Controller

  get "/mentions/:mention" do |env|
    mention = env.params.url["mention"]

    unless mention.includes?("@") # bare handle
      handles = Tag::Mention.qualified_handles(mention)
      not_found unless handles.size == 1
      redirect mention_path(handles.first), 301
    end

    href = Tag::Mention.dominant_href(mention)
    not_found unless href

    collection = Tag::Mention.all_objects(href, **cursor_pagination_params(env))
    count = Tag::Mention.all_objects_count(mention)

    not_found if collection.empty?

    follow = Relationship::Content::Follow::Mention.find?(actor: env.account.actor, href: href)

    ok "mentions/index", env: env, mention: mention, collection: collection, count: count, follow: follow
  end

  post "/mentions/:mention/follow" do |env|
    mention = env.params.url["mention"]

    href = Tag::Mention.dominant_href(mention)
    not_found unless href

    collection = Tag::Mention.all_objects(href)
    count = Tag::Mention.all_objects_count(mention)

    not_found if collection.empty?

    follow = Relationship::Content::Follow::Mention.find_or_new(actor: env.account.actor, href: href)
    follow.save if follow.new_record?

    if in_turbo_frame?
      ok "mentions/index", env: env, mention: mention, collection: collection, count: count, follow: follow
    else
      redirect back_path
    end
  end

  post "/mentions/:mention/unfollow" do |env|
    mention = env.params.url["mention"]

    href = Tag::Mention.dominant_href(mention)
    not_found unless href

    collection = Tag::Mention.all_objects(href)
    count = Tag::Mention.all_objects_count(mention)

    not_found if collection.empty?

    follow = Relationship::Content::Follow::Mention.find?(actor: env.account.actor, href: href)
    follow.destroy if follow

    if in_turbo_frame?
      ok "mentions/index", env: env, mention: mention, collection: collection, count: count, follow: nil
    else
      redirect back_path
    end
  end
end
