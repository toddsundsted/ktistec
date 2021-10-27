require "../../src/models/account"

class Account
  private def cost
    4 # reduce the cost of computing a bcrypt hash
  end
end

def self.register(username = random_username, password = random_password, *, base_uri = "https://test.test/actors")
  Account.new(
    actor: ActivityPub::Actor.new(
      iri: "#{base_uri}/#{username}",
      username: username
    ),
    username: username,
    password: password
  ).save
end
