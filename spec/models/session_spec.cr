require "../spec_helper"

Spectator.describe Session do
  setup_spec

  let(username) { random_string }
  let(password) { random_string }

  let(account) { Account.new(username, password).save }
  subject { described_class.new(account).save }

  describe "#body=" do
    it "sets the body" do
      body = {"foo" => "bar"}
      expect{subject.body = body}.to change{subject.body_json}
    end
  end

  describe "#body" do
    it "gets the body" do
      body = subject.body = {"foo" => "bar"}
      expect(subject.body).to eq(body)
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
