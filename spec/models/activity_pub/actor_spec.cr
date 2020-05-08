require "../../spec_helper"

class FooBarActor < ActivityPub::Actor
end

Spectator.describe ActivityPub::Actor do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  let(username) { random_string }
  let(password) { random_string }

  let(account) { Account.new(username, password).save }

  let(foo_bar) { FooBarActor.new.save }

  describe "#public_key" do
    it "returns the public key" do
      expect(foo_bar.public_key).to be_a(OpenSSL::RSA)
    end
  end

  describe "#private_key" do
    it "returns the private key" do
      expect(foo_bar.private_key).to be_a(OpenSSL::RSA)
    end
  end

  context "when using the keypair" do
    it "verifies the signed message" do
      message = "this is a test"
      private_key = foo_bar.private_key
      public_key = foo_bar.public_key
      if private_key && public_key
        signature = private_key.sign(OpenSSL::Digest.new("SHA256"), message)
        expect(public_key.verify(OpenSSL::Digest.new("SHA256"), signature, message)).to be_true
      end
    end
  end

  describe ".from_json_ld" do
    it "creates a new instance" do
      json = <<-JSON
        {
          "@context":[
            "https://www.w3.org/ns/activitystreams",
            "https://w3id.org/security/v1"
          ],
          "@id":"https://test.test/foo_bar",
          "@type":"FooBarActor",
          "preferredUsername":"foo_bar",
          "publicKey":{
            "id":"https://test.test/foo_bar#public-key",
            "owner":"https://test.test/foo_bar",
            "publicKeyPem":"---PEM PUBLIC KEY---"
          },
          "privateKey":{
            "id":"https://test.test/foo_bar#private-key",
            "owner":"https://test.test/foo_bar",
            "privateKeyPem":"---PEM PRIVATE KEY---"
          },

          "name":"Foo Bar",
          "summary": "<p></p>",
          "icon": {
            "type": "Image",
            "mediaType": "image/jpeg",
            "url": "icon link"
          },
          "image": {
            "type": "Image",
            "mediaType": "image/jpeg",
            "url": "image link"
          }
        }
      JSON
      actor = described_class.from_json_ld(json).save.as_a(FooBarActor)
      expect(actor.aid).to eq("https://test.test/foo_bar")
      expect(actor.username).to eq("foo_bar")
      expect(actor.pem_public_key).to eq("---PEM PUBLIC KEY---")
      expect(actor.pem_private_key).to eq("---PEM PRIVATE KEY---")
      expect(actor.name).to eq("Foo Bar")
      expect(actor.summary).to eq("<p></p>")
      expect(actor.icon).to eq("icon link")
      expect(actor.image).to eq("image link")
    end
  end
end
