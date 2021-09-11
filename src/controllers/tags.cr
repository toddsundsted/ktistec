require "../framework/controller"
require "../models/tag/hashtag"

class TagsController
  include Ktistec::Controller

  skip_auth ["/tags/:hashtag"], GET

  get "/tags/:hashtag" do |env|
    hashtag = env.params.url["hashtag"]
    if (collection = Tag::Hashtag.objects_with_tag(hashtag, *pagination_params(env))).empty?
      not_found
    end
    accepts?("text/html") ?
      render_tags_html(env, collection) :
      render_tags_json(env, collection)
  end

  private def self.render_tags_html(env, collection, query = nil, message = nil)
    env.response.content_type = "text/html"
    render "src/views/tags/index.html.slang", "src/views/layouts/default.html.ecr"
  end

  private def self.render_tags_json(env, collection, query = nil, message = nil)
    env.response.content_type = "application/json"
    render "src/views/partials/collection.json.ecr"
  end
end
