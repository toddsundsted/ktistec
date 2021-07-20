require "../framework/controller"
require "../views/view_helper"
require "../models/activity_pub/activity/follow"

class RelationshipsController
  include Ktistec::Controller
  include Ktistec::ViewHelper

  skip_auth ["/actors/:username/following"], GET
  skip_auth ["/actors/:username/followers"], GET

  get "/actors/:username/:relationship" do |env|
    unless (account = get_account(env))
      not_found
    end
    actor = account.actor
    unless (related = all_related(env, actor, public: env.account? != account))
      bad_request
    end

    ok "relationships/index"
  end

  private def self.get_account(env)
    Account.find?(username: env.params.url["username"]?)
  end

  private def self.all_related(env, actor, public = true)
    case env.params.url["relationship"]?
    when "following"
      actor.all_following(*pagination_params(env), public: public)
    when "followers"
      actor.all_followers(*pagination_params(env), public: public)
    else
    end
  end
end
