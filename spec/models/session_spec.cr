require "../../src/models/session"

require "../spec_helper/base"

Spectator.describe Session do
  setup_spec

  let(username) { random_username }
  let(password) { random_password }

  let(account) { Account.new(username, password).save }
  subject { described_class.new(account).save }

  describe "#body=" do
    it "sets the body" do
      subject.body = {"foo" => "bar"}
      expect(subject.body_json).to eq(%q|{"foo":"bar"}|)
    end
  end

  describe "#body" do
    it "gets the body" do
      subject.body_json = %q|{"foo":"bar"}|
      expect(subject.body).to eq({"foo" => "bar"})
    end
  end

  describe "#string" do
    it "stores a string value in the session" do
      subject.string("foo", "bar")
      expect(subject.body_json).to eq(%q|{"foo":"bar"}|)
    end
  end

  describe "#string" do
    it "retrieves a string value from the session" do
      subject.body_json = %q|{"foo":"bar"}|
      expect(subject.string("foo")).to eq("bar")
    end
  end

  describe "#string?" do
    it "retrieves a string value from the session" do
      subject.body_json = %q|{"foo":"bar"}|
      expect(subject.string?("foo")).to eq("bar")
    end

    it "returns nil" do
      subject.body_json = %q|{"foo":"bar"}|
      expect(subject.string?("fxx")).to be_nil
    end
  end

  describe "#delete" do
    it "deletes the entry from the session" do
      subject.string("foo", "bar")
      expect(subject.delete("foo")).to eq("bar")
      expect(subject.string?("foo")).to be_nil
    end
  end

  context "with an expiry in the future" do
    it "stores the expiration date" do
      subject.string("foo", "bar", expires_in: 5.seconds)
      expect(subject.body_json).to match(/{"foo":{"value":"bar","expiry":[0-9]+}}/)
    end

    it "retrieves a string value from the session" do
      subject.body_json = %Q|{"foo":{"value":"bar","expiry":#{Time.utc.to_unix + 60}}}|
      expect(subject.string("foo")).to eq("bar")
    end

    it "retrieves a string value from the session" do
      subject.body_json = %Q|{"foo":{"value":"bar","expiry":#{Time.utc.to_unix + 60}}}|
      expect(subject.string?("foo")).to eq("bar")
    end

    it "deletes the entry from the session" do
      subject.body_json = %Q|{"foo":{"value":"bar","expiry":#{Time.utc.to_unix + 60}}}|
      expect(subject.delete("foo")).to eq("bar")
      expect(subject.string?("foo")).to be_nil
    end
  end

  context "with an expiry in the past" do
    it "stores the expiration date" do
      subject.string("foo", "bar", expires_in: -5.seconds)
      expect(subject.body_json).to match(/{"foo":{"value":"bar","expiry":[0-9]+}}/)
    end

    it "returns nil" do
      subject.body_json = %Q|{"foo":{"value":"bar","expiry":#{Time.utc.to_unix - 60}}}|
      expect(subject.string("foo")).to be_nil
    end

    it "returns nil" do
      subject.body_json = %Q|{"foo":{"value":"bar","expiry":#{Time.utc.to_unix - 60}}}|
      expect(subject.string?("foo")).to be_nil
    end

    it "returns nil" do
      subject.body_json = %Q|{"foo":{"value":"bar","expiry":#{Time.utc.to_unix - 60}}}|
      expect(subject.delete("foo")).to be_nil
      expect(subject.string?("foo")).to be_nil
    end
  end

  describe "#account=" do
    it "sets the account" do
      account = Account.new(random_username, random_password).save
      expect{subject.account = account}.to change{subject.account_id}
    end
  end

  describe "#account" do
    it "gets the account" do
      account = subject.account = Account.new(random_username, random_password).save
      expect(subject.account).to eq(account)
    end
  end

  describe "#generate_jwt" do
    it "generates a web token" do
      expect(subject.generate_jwt).to match(/^([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)$/)
    end
  end

  describe ".find_by_jwt?" do
    let(jwt) { subject.generate_jwt }

    it "returns the session" do
      expect(described_class.find_by_jwt?(jwt)).to eq(subject)
    end

    it "returns nil" do
      expect(described_class.find_by_jwt?(described_class.new.generate_jwt)).to be_nil
    end

    it "returns nil" do
      expect(described_class.find_by_jwt?("garbage.garbage.garbage")).to be_nil
    end
  end

  let(anonymous) { described_class.new.save }

  describe ".clean_up_stale_sessions" do
    before_each do
      Ktistec.database.exec(
        "UPDATE sessions SET updated_at = date('now', '-2 days') WHERE id IN (?, ?)",
        anonymous.id,
        subject.id
      )
    end

    it "removes old, anonymous sessions" do
      expect{Session.clean_up_stale_sessions}.to change{Session.count}.by(-1)
    end
  end
end
