require "../../spec_helper"

class SerializedModel
  include Ktistec::Model(Serialized)
end

Spectator.describe Ktistec::Model::Serialized do
  subject { SerializedModel }

  describe ".new" do
    it "includes Ktistec::Model::Serialized" do
      expect(subject.new).to be_a(Ktistec::Model::Serialized)
    end
  end

  describe ".dig?" do
    let(json) { JSON.parse(%<{"foo":5}>) }

    it "returns the value as the specified type" do
      expect(subject.dig?(json, "foo", as: Int64)).to eq(5)
    end
  end

  describe ".dig_value?" do
    let(json) { JSON.parse(%<{"foo":{"bar":3,"baz":5}}>) }

    it "returns the result of the block" do
      result = subject.dig_value?(json, "foo") do |j|
        if (bar = subject.dig?(j, "bar", as: Int64)) && (baz = subject.dig?(j, "baz", as: Int64))
          bar + baz
        end
      end
      expect(result).to eq(8)
    end
  end

  describe ".dig_values?" do
    context "given a nested object" do
      let(json) { JSON.parse(%<{"foo":{"bar":3,"baz":5}}>) }

      it "returns the result of the block as an array" do
        result = subject.dig_values?(json, "foo") do |j|
          if (bar = subject.dig?(j, "bar", as: Int64)) && (baz = subject.dig?(j, "baz", as: Int64))
            bar + baz
          end
        end
        expect(result).to eq([8])
      end
    end

    context "given an array of nested objects" do
      let(json) { JSON.parse(%<{"foo":[{"bar":3,"baz":5}]}>) }

      it "returns the results of the block" do
        result = subject.dig_values?(json, "foo") do |j|
          if (bar = subject.dig?(j, "bar", as: Int64)) && (baz = subject.dig?(j, "baz", as: Int64))
            bar + baz
          end
        end
        expect(result).to eq([8])
      end
    end
  end

  describe ".dig_id?" do
    context "given a nested object" do
      let(json) { JSON.parse(%<{"foo":{"@id":"https://test.test/bar"}}>) }

      it "returns the identifier" do
        expect(subject.dig_id?(json, "foo")).to eq("https://test.test/bar")
      end
    end

    context "given an identifier" do
      let(json) { JSON.parse(%<{"foo":"https://test.test/bar"}>) }

      it "returns the identifier" do
        expect(subject.dig_id?(json, "foo")).to eq("https://test.test/bar")
      end
    end
  end

  describe ".dig_ids?" do
    context "given a nested object" do
      let(json) { JSON.parse(%<{"foo":{"@id":"https://test.test/bar"}}>) }

      it "returns the identifier as an array" do
        expect(subject.dig_ids?(json, "foo")).to eq(["https://test.test/bar"])
      end
    end

    context "given an identifier" do
      let(json) { JSON.parse(%<{"foo":"https://test.test/bar"}>) }

      it "returns the identifier as an array" do
        expect(subject.dig_ids?(json, "foo")).to eq(["https://test.test/bar"])
      end
    end

    context "given an array of nested objects" do
      let(json) { JSON.parse(%<{"foo":[{"@id":"https://test.test/bar"}]}>) }

      it "returns the identifiers" do
        expect(subject.dig_ids?(json, "foo")).to eq(["https://test.test/bar"])
      end
    end

    context "given an array of identifiers" do
      let(json) { JSON.parse(%<{"foo":["https://test.test/bar"]}>) }

      it "returns the identifiers" do
        expect(subject.dig_ids?(json, "foo")).to eq(["https://test.test/bar"])
      end
    end
  end
end
