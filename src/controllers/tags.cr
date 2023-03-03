require "../framework/controller"
require "../models/tag/hashtag"

class TagsController
  include Ktistec::Controller

  skip_auth ["/tags/:hashtag"], GET

  get "/tags/:hashtag" do |env|
    hashtag = env.params.url["hashtag"]
    if (collection = Tag::Hashtag.public_objects(hashtag, **pagination_params(env))).empty?
      not_found
    end
    ok "tags/index"
  end
end
