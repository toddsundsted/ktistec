require "../../src/models/account"

class Account
  private def cost
    4 # reduce the cost of computing a bcrypt hash
  end
end

def self.register(username = random_username, password = random_password, *, with_keys = false)
  pem_public_key, pem_private_key =
    if with_keys
      keypair = OpenSSL::RSA.generate(2048, 17)
      {keypair.public_key.to_pem, keypair.to_pem}
    else
      {nil, nil}
    end
  Account.new(
    actor: ActivityPub::Actor.new(iri: "https://test.test/actors/#{username}", username: username, pem_public_key: pem_public_key, pem_private_key: pem_private_key),
    username: username,
    password: password
  ).save
end
