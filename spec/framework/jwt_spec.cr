require "../spec_helper"

Spectator.describe Ktistec::JWT do
  let(secret) { "my$ecretK3y" }
  let(payload) { {"foo" => "bar"} }
  let(token) { "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJmb28iOiJiYXIifQ.HvpjHn5PxYHBApB3qURCJzM2hOer8a5mkO4lstal06k" }

  describe ".encode" do
    it "encodes the payload" do
      expect(described_class.encode(payload, secret)).to eq(token)
    end
  end

  describe ".decode" do
    it "decodes the token" do
      expect(described_class.decode(token, secret)).to eq(payload)
    end

    it "raises an error if the token is not well-formed" do
      expect{described_class.decode("fbb", secret)}.to raise_error(Ktistec::JWT::Error)
    end

    it "raises an error if the token is not encoded correctly" do
      expect{described_class.decode("f.b.b", secret)}.to raise_error(Ktistec::JWT::Error)
    end

    it "raise an error if the signature is not correct" do
      expect{described_class.decode(token[0..-2], secret)}.to raise_error(Ktistec::JWT::Error)
    end
  end

  describe ".expired?" do
    it "returns true if payload is expired" do
      payload = JSON.parse({"iat" => 2.months.ago}.to_json)
      expect(described_class.expired?(payload)).to be_true
    end

    it "returns false if payload is not expired" do
      payload = JSON.parse({"iat" => 2.days.ago}.to_json)
      expect(described_class.expired?(payload)).to be_false
    end
  end
end
