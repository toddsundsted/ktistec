require "../framework/controller"
require "../models/tag/mention"
require "../models/relationship/content/follow/mention"

class MentionsController
  include Ktistec::Controller

  get "/mentions/:mention" do |env|
    mention = env.params.url["mention"]

    collection = Tag::Mention.all_objects(mention, **pagination_params(env))

    if collection.empty?
      not_found
    end

    follow = Relationship::Content::Follow::Mention.find?(actor: env.account.actor, name: mention)

    ok "mentions/index"
  end

  post "/mentions/:mention/follow" do |env|
    mention = env.params.url["mention"]

    if (collection = Tag::Mention.all_objects(mention)).empty?
      not_found
    end

    if Relationship::Content::Follow::Mention.find?(actor: env.account.actor, name: mention)
      bad_request
    end

    follow = Relationship::Content::Follow::Mention.new(actor: env.account.actor, name: mention).save

    if turbo_frame?
      ok "mentions/index"
    else
      redirect back_path
    end
  end

  post "/mentions/:mention/unfollow" do |env|
    mention = env.params.url["mention"]

    if (collection = Tag::Mention.all_objects(mention)).empty?
      not_found
    end

    unless (follow = Relationship::Content::Follow::Mention.find?(actor: env.account.actor, name: mention))
      bad_request
    end

    follow.destroy
    follow = nil

    if turbo_frame?
      ok "mentions/index"
    else
      redirect back_path
    end
  end
end
