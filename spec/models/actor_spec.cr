require "../spec_helper"

Spectator.describe Actor do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  def random_string
    ('a'..'z').to_a.shuffle.first(8).join
  end

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

  describe "#sessions" do
    it "gets related sessions" do
      expect(subject.sessions).to be_empty
    end
  end
end
