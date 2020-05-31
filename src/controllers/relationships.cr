require "../framework"

class RelationshipsController
  include Balloon::Controller

  private macro actor_relationship_path
    "/actors/#{env.params.url["username"]}/#{env.params.url["relationship"]}"
  end

  get "/actors/:username/:relationship" do |env|
    unless (actor = get_actor(env))
      not_found
    end
    unless (related = get_related(actor, env))
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
    unless (actor = get_actor(env))
      not_found
    end
    unless (other = get_other(env))
      bad_request
    end
    unless (related = make_related(actor, other, env))
      bad_request
    end
    unless related.valid?
      bad_request
    end

    related.save

    env.redirect actor_relationship_path
  end

  delete "/actors/:username/:relationship/:id" do |env|
    unless (actor = get_actor(env))
      not_found
    end
    unless (relationship = find_related(env))
      bad_request
    end
    unless actor.iri.in?({relationship.from_iri, relationship.to_iri})
      not_found
    end

    relationship.destroy

    env.redirect actor_relationship_path
  end

  private def self.pagination_params(env)
    {
      env.params.query["page"]?.try(&.to_u16) || 0_u16,
      env.params.query["size"]?.try(&.to_u16) || 10_u16
    }
  end

  private def self.get_actor(env)
    (account = env.current_account?) &&
      (username = env.params.url["username"]?) &&
      account.username == username &&
      (actor = account.actor?)
    actor
  end

  private def self.get_other(env)
    (iri = env.params.body["iri"]? || env.params.json["iri"]?) &&
      (other = ActivityPub::Actor.find?(iri.to_s))
    other
  end

  private def self.get_related(actor, env)
    case env.params.url["relationship"]?
    when "following"
      actor.all_following(*pagination_params(env))
    when "followers"
      actor.all_followers(*pagination_params(env))
    else
    end
  end

  private def self.make_related(actor, other, env)
    case env.params.url["relationship"]?
    when "following"
      actor.follow(other)
    when "followers"
      other.follow(actor)
    else
    end
  end

  private def self.find_related(env)
    case env.params.url["relationship"]?
    when "following"
      Relationship::Social::Follow.find(env.params.url["id"].to_i)
    when "followers"
      Relationship::Social::Follow.find(env.params.url["id"].to_i)
    else
    end
  end
end
