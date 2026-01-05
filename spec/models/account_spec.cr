require "../../src/models/account"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Account do
  setup_spec

  let(username) { random_username }
  let(password) { random_password }

  subject { described_class.new(username: username, password: password, language: "en").save }

  describe "#password=" do
    it "changes the encrypted_password" do
      expect{subject.password = "foobar"}.to change{subject.encrypted_password}
    end

    it "does not change the encrypted_password if the password is nil" do
      expect{subject.password = nil}.not_to change{subject.encrypted_password}
    end

    it "does not change the encrypted_password if the password is an empty string" do
      expect{subject.password = ""}.not_to change{subject.encrypted_password}
    end
  end

  describe "#encrypted_password" do
    it "returns the encrypted password" do
      expect(subject.encrypted_password).to match(/^\$2a\$[0-9]+\$/)
    end
  end

  describe "#check_password" do
    it "returns true if supplied password is correct" do
      expect(subject.check_password(password)).to be_true
    end

    it "returns false if supplied password is not correct" do
      expect(subject.check_password("foobar")).to be_false
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

    it "rejects the language if blank" do
      new_account = described_class.new(username: "", password: "", language: "")
      expect(new_account.validate["language"]).to eq(["cannot be blank"])
    end

    it "rejects the language as unsupported" do
      new_account = described_class.new(username: "", password: "", language: "123")
      expect(new_account.validate["language"]).to eq(["is unsupported"])
    end

    it "rejects the timezone as unsupported" do
      new_account = described_class.new(username: "", password: "", timezone: "Foo/Bar")
      expect(new_account.validate["timezone"]).to eq(["is unsupported"])
    end

    it "rejects the default editor as invalid" do
      new_account = described_class.new(username: "", password: "", default_editor: "text/plain")
      expect(new_account.validate["default_editor"]).to eq(["is not a valid editor"])
    end
  end

  context "given an actor to associate with" do
    let_create(:actor)

    describe "#actor=" do
      it "updates the iri" do
        expect{subject.actor = actor}.to change{subject.iri}
      end
    end

    describe "#actor" do
      it "updates the actor" do
        expect{subject.iri = actor.iri}.to change{subject.actor?}
      end
    end

    describe "#save" do
      before_each { subject.actor = actor }

      it "updates the associated actor's public key" do
        expect{subject.save}.to change{actor.pem_public_key}
      end

      it "updates the associated actor's private key" do
        expect{subject.save}.to change{actor.pem_private_key}
      end
    end
  end

  describe "#sessions" do
    it "gets related sessions" do
      expect(subject.sessions).to be_empty
    end
  end

  describe ".monthly_active_accounts_count" do
    let!(actor) { register.actor }

    context "given an activity within the last 30 days" do
      let_create!(:activity, actor: actor, published: 15.days.ago)

      it "returns a count of 1" do
        count = described_class.monthly_active_accounts_count
        expect(count).to eq(1)
      end

      context "that was undone" do
        before_each { activity.undo! }

        it "returns a count of 0" do
          count = described_class.monthly_active_accounts_count
          expect(count).to eq(0)
        end
      end
    end

    context "given an activity older than 30 days" do
      let_create!(:activity, actor: actor, published: 45.days.ago)

      it "returns a count of 0" do
        count = described_class.monthly_active_accounts_count
        expect(count).to eq(0)
      end
    end
  end
end
