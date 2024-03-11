require "../framework/controller"
require "../models/activity_pub/activity/follow"

class RelationshipsController
  include Ktistec::Controller

  skip_auth ["/actors/:username/following"], GET
  skip_auth ["/actors/:username/followers"], GET

  private enum Social
    Followers
    Following
  end

  private enum Activity
    Likes
    Shares
  end

  get "/actors/:username/:relationship" do |env|
    unless (account = get_account(env))
      not_found
    end

    actor = account.actor

    if (relationship = Social.parse?(env.params.url["relationship"]))
      related = all_related_actors(env, actor, relationship, public: env.account? != account)
      ok "relationships/actors", env: env, related: related
    elsif (relationship = Activity.parse?(env.params.url["relationship"]))
      objects = all_related_objects(env, actor, relationship)
      ok "relationships/objects", env: env, objects: objects
    else
      bad_request
    end
  end

  private def self.get_account(env)
    Account.find?(username: env.params.url["username"]?)
  end

  private def self.all_related_actors(env, actor, relationship, public = true)
    case relationship
    in Social::Following
      actor.all_following(**pagination_params(env), public: public)
    in Social::Followers
      actor.all_followers(**pagination_params(env), public: public)
    end
  end

  private def self.all_related_objects(env, actor, relationship)
    case relationship
    in Activity::Likes
      actor.likes(**pagination_params(env))
    in Activity::Shares
      actor.announces(**pagination_params(env))
    end
  end
end
