require "../framework/controller"
require "../views/view_helper"

class EverythingController
  include Ktistec::Controller
  extend Ktistec::ViewHelper

  get "/everything" do |env|
    collection = ActivityPub::Object.federated_posts(*pagination_params(env))

    accepts?("text/html") ?
      render_html(env, collection) :
      render_json(env, collection)
  end

  private def self.render_html(env, collection)
    env.response.content_type = "text/html"
    render "src/views/everything/index.html.slang", "src/views/layouts/default.html.ecr"
  end

  private def self.render_json(env, collection)
    env.response.content_type = "application/json"
    render "src/views/partials/collection.json.ecr"
  end
end
