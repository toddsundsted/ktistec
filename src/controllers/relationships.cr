require "../framework"

class RelationshipsController
  include Balloon::Controller

  skip_auth ["/actors/:username/:relationship"], GET

  get "/actors/:username/:relationship" do |env|
    unless (account = get_account(env))
      not_found
    end
    actor = account.actor
    unless (related = all_related(env, actor, public: env.current_account? != account))
      bad_request
    end

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/relationships/index.html.ecr", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/relationships/index.json.ecr"
    end
  end

  post "/actors/:username/:relationship" do |env|
    unless (account = get_account(env))
      not_found
    end
    unless env.current_account? == account
      forbidden
    end
    actor = account.actor
    unless (other = find_other(env))
      bad_request
    end
    unless (relationship = make_relationship(env, actor, other))
      bad_request
    end
    unless relationship.valid?
      bad_request
    end

    relationship.save

    env.redirect actor_relationships_path(actor)
  end

  delete "/actors/:username/:relationship/:id" do |env|
    unless (account = get_account(env))
      not_found
    end
    unless env.current_account? == account
      forbidden
    end
    actor = account.actor
    unless (relationship = find_relationship(env))
      bad_request
    end
    unless actor.iri.in?({relationship.from_iri, relationship.to_iri})
      forbidden
    end

    relationship.destroy

    env.redirect actor_relationships_path(actor)
  end

  private def self.pagination_params(env)
    {
      env.params.query["page"]?.try(&.to_u16) || 0_u16,
      env.params.query["size"]?.try(&.to_u16) || 10_u16
    }
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

  private def self.make_relationship(env, actor, other)
    case env.params.url["relationship"]?
    when "following"
      actor.follow(other, confirmed: true, visible: true)
    when "followers"
      other.follow(actor, confirmed: true, visible: true)
    else
    end
  end

  private def self.find_relationship(env)
    case env.params.url["relationship"]?
    when "following"
      Relationship::Social::Follow.find?(env.params.url["id"].to_i)
    when "followers"
      Relationship::Social::Follow.find?(env.params.url["id"].to_i)
    else
    end
  end

  private def self.find_other(env)
    (iri = env.params.body["iri"]? || env.params.json["iri"]?) &&
      (other = ActivityPub::Actor.find?(iri.to_s))
    other
  end
end
