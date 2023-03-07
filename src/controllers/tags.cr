require "../framework/controller"
require "../models/tag/hashtag"
require "../models/relationship/content/follow/hashtag"

class TagsController
  include Ktistec::Controller

  skip_auth ["/tags/:hashtag"], GET

  get "/tags/:hashtag" do |env|
    hashtag = env.params.url["hashtag"]

    collection =
      if env.account?
        Tag::Hashtag.all_objects(hashtag, **pagination_params(env))
      else
        Tag::Hashtag.public_objects(hashtag, **pagination_params(env))
      end

    if collection.empty?
      not_found
    end

    if env.account?
      follow = Relationship::Content::Follow::Hashtag.find?(actor: env.account.actor, name: hashtag)
    end

    ok "tags/index"
  end

  post "/tags/:hashtag/follow" do |env|
    hashtag = env.params.url["hashtag"]

    if (collection = Tag::Hashtag.all_objects(hashtag)).empty?
      not_found
    end

    if Relationship::Content::Follow::Hashtag.find?(actor: env.account.actor, name: hashtag)
      bad_request
    end

    follow = Relationship::Content::Follow::Hashtag.new(actor: env.account.actor, name: hashtag).save

    if turbo_frame?
      ok "tags/index"
    else
      redirect back_path
    end
  end

  post "/tags/:hashtag/unfollow" do |env|
    hashtag = env.params.url["hashtag"]

    if (collection = Tag::Hashtag.all_objects(hashtag)).empty?
      not_found
    end

    unless (follow = Relationship::Content::Follow::Hashtag.find?(actor: env.account.actor, name: hashtag))
      bad_request
    end

    follow.destroy
    follow = nil

    if turbo_frame?
      ok "tags/index"
    else
      redirect back_path
    end
  end
end
