require "../framework/controller"
require "../models/filter_term"

class FiltersController
  include Ktistec::Controller

  # Authorizes filter term access.
  #
  # Returns the filter term if the authenticated user owns it, `nil`
  # otherwise.
  #
  private def self.get_filter_term(env, id)
    if (term = FilterTerm.find?(id))
      if (account = env.account?) && account.actor == term.actor
        term
      end
    end
  end

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
    unless (term = get_filter_term(env, id_param(env)))
      not_found
    end

    term.destroy

    redirect back_path
  end

  private def self.params(env)
    params = (env.params.body.presence || env.params.json.presence).not_nil!
    {
      "term" => params["term"]?.try(&.to_s),
    }
  end
end
