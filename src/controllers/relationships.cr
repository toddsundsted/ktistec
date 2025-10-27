require "../framework/controller"

class RelationshipsController
  include Ktistec::Controller

  skip_auth ["/actors/:username/following"], GET
  skip_auth ["/actors/:username/followers"], GET

  # Authorizes account access for public relationship data.
  #
  # Returns the account if it exists, `nil` otherwise.
  #
  # Used for viewing relationships (following/followers) where
  # public/private filtering is handled separately.
  #
  private def self.get_account(env)
    Account.find?(username: env.params.url["username"])
  end

  # Authorizes account access for private relationship data.
  #
  # Returns the account if the authenticated user owns it, `nil`
  # otherwise.
  #
  # Used for viewing relationships (likes/shares) which should only be
  # accessible to the account owner.
  #
  private def self.get_account_with_ownership(env)
    if (account = Account.find?(username: env.params.url["username"]))
      if env.account? == account
        account
      end
    end
  end

  get "/actors/:username/following" do |env|
    unless (account = get_account(env))
      not_found
    end

    related = account.actor.all_following(**pagination_params(env), public: env.account? != account)
    ok "relationships/actors", env: env, related: related, title: "Following"
  end

  get "/actors/:username/followers" do |env|
    unless (account = get_account(env))
      not_found
    end

    related = account.actor.all_followers(**pagination_params(env), public: env.account? != account)
    ok "relationships/actors", env: env, related: related, title: "Followers"
  end

  get "/actors/:username/likes" do |env|
    unless (account = get_account_with_ownership(env))
      not_found
    end

    objects = account.actor.likes(**pagination_params(env))
    ok "relationships/objects", env: env, objects: objects, title: "Likes"
  end

  get "/actors/:username/shares" do |env|
    unless (account = get_account_with_ownership(env))
      not_found
    end

    objects = account.actor.announces(**pagination_params(env))
    ok "relationships/objects", env: env, objects: objects, title: "Shares"
  end
end
