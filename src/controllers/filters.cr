require "../framework/controller"
require "../models/filter_term"

class FiltersController
  include Ktistec::Controller

  get "/filters" do |env|
    actor = env.account.actor

    terms = actor.terms(**pagination_params(env))

    ok "filters/index", env: env, terms: terms
  end

  post "/filters" do |env|
    actor = env.account.actor

    term = FilterTerm.new(params(env)).assign(actor: actor)

    if term.valid?
      term.save

      redirect filters_path
    else
      unprocessable_entity "filters/form", env: env, term: term
    end
  end

  delete "/filters/:id" do |env|
    actor = env.account.actor

    unless (term = FilterTerm.find?(env.params.url["id"].to_i64))
      not_found
    end

    unless term.actor == actor
      forbidden
    end

    term.destroy

    redirect back_path
  end

  private def self.params(env)
    params = (env.params.body.presence || env.params.json.presence).not_nil!
    {
      "term" => params["term"]?.try(&.to_s)
    }
  end
end
