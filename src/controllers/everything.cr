require "../framework/controller"

class EverythingController
  include Ktistec::Controller

  get "/everything" do |env|
    collection = ActivityPub::Object.federated_posts(**pagination_params(env))

    ok "everything/index", env: env, collection: collection
  end
end
