require "../spec_helper"

Spectator.describe Account do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  let(username) { random_string }
  let(password) { random_string }

  subject { described_class.new(username, password).save }

  describe "#password=" do
    it "sets the password" do
      expect{subject.password = "foobar"}.to change{subject.encrypted_password}
    end
  end

  describe "#encrypted_password" do
    it "returns the encrypted password" do
      expect(subject.encrypted_password).to match(/^\$2a\$[0-9]+\$/)
    end
  end

  describe "#valid_password?" do
    it "returns true if supplied password is valid" do
      expect(subject.valid_password?(password)).to be_true
    end

    it "returns false if supplied password is not valid" do
      expect(subject.valid_password?("foobar")).to be_false
    end
  end

  describe "#validate" do
    it "rejects the username as too short" do
      new_account = described_class.new(username: "", password: "")
      expect(new_account.validate["username"]).to eq(["is too short"])
    end

    it "rejects the username as not unique" do
      new_account = described_class.new(username: subject.username, password: password)
      expect(new_account.validate["username"]).to eq(["must be unique"])
    end

    it "rejects the password as too short" do
      new_account = described_class.new(username: "", password: "a1!")
      expect(new_account.validate["password"]).to eq(["is too short"])
    end

    it "rejects the password as weak" do
      new_account = described_class.new(username: "", password: "abc123")
      expect(new_account.validate["password"]).to eq(["is weak"])
    end
  end

  describe "#public_key" do
    it "returns the public key" do
      expect(subject.public_key).to be_a(OpenSSL::RSA)
    end
  end

  describe "#private_key" do
    it "returns the private key" do
      expect(subject.private_key).to be_a(OpenSSL::RSA)
    end
  end

  context "when using the keypair" do
    it "verifies the signed message" do
      message = "this is a test"
      signature = subject.private_key.sign(OpenSSL::Digest.new("SHA256"), message)
      expect(subject.public_key.verify(OpenSSL::Digest.new("SHA256"), signature, message)).to be_true
    end
  end

  context "given an actor to associate with" do
    let(actor) { ActivityPub::Actor.new(username: random_string).save }

    describe "#actor=" do
      it "updates the username" do
        expect{subject.actor = actor}.to change{subject.username}
      end
    end

    describe "#actor" do
      it "updates the actor" do
        expect{subject.username = actor.username.not_nil!}.to change{subject.actor?}
      end
    end
  end

  describe "#sessions" do
    it "gets related sessions" do
      expect(subject.sessions).to be_empty
    end
  end
end
