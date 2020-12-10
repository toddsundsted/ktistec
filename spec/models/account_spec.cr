require "../../src/models/account"

require "../spec_helper/model"

Spectator.describe Account do
  setup_spec

  let(username) { random_username }
  let(password) { random_password }

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

    it "rejects the username as containing invalid characters" do
      new_account = described_class.new(username: "@", password: "")
      expect(new_account.validate["username"]).to eq(["contains invalid characters"])
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

  context "given an actor to associate with" do
    let(actor) do
      ActivityPub::Actor.new(
        iri: "https://test.test/#{random_string}"
      ).save
    end

    describe "#actor=" do
      it "updates the iri" do
        expect{subject.actor = actor}.to change{subject.iri}
      end
    end

    describe "#actor" do
      it "updates the actor" do
        expect{subject.iri = actor.iri.not_nil!}.to change{subject.actor?}
      end
    end
  end

  describe "#sessions" do
    it "gets related sessions" do
      expect(subject.sessions).to be_empty
    end
  end
end
