require "../framework/controller"

class EverythingController
  include Ktistec::Controller

  get "/everything" do |env|
    collection = ActivityPub::Object.federated_posts(**cursor_pagination_params(env))

    ok "everything/index", env: env, collection: collection
  end
end
