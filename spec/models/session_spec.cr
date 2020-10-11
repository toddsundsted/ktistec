require "../spec_helper"

Spectator.describe Session do
  setup_spec

  let(username) { random_string }
  let(password) { random_string }

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
  end

  describe "#account=" do
    it "sets the account" do
      account = Account.new(random_string, random_string).save
      expect{subject.account = account}.to change{subject.account_id}
    end
  end

  describe "#account" do
    it "gets the account" do
      account = subject.account = Account.new(random_string, random_string).save
      expect(subject.account).to eq(account)
    end
  end
end
