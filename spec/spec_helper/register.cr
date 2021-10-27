require "../../src/models/account"

class Account
  private def cost
    4 # reduce the cost of computing a bcrypt hash
  end
end

def self.register(username = random_username, password = random_password)
  Account.new(
    actor: ActivityPub::Actor.new(
      iri: "https://test.test/actors/#{username}",
      username: username
    ),
    username: username,
    password: password
  ).save
end
