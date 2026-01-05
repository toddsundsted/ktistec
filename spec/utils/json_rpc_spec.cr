require "../../src/utils/json_rpc"

require "../spec_helper/base"

Spectator.describe JSON::RPC::Request do
  describe ".from_json" do
    it "parses request with string id" do
      json = %Q|{"jsonrpc": "2.0", "id": "123", "method": "test"}|
      request = described_class.from_json(json)

      expect(request.jsonrpc).to eq("2.0")
      expect(request.id).to eq("123")
      expect(request.method).to eq("test")
      expect(request.params).to be_nil
      expect(request.notification?).to be_false
    end

    it "parses request with integer id" do
      json = %Q|{"jsonrpc": "2.0", "id": 456, "method": "test"}|
      request = described_class.from_json(json)

      expect(request.jsonrpc).to eq("2.0")
      expect(request.id).to eq(456)
      expect(request.method).to eq("test")
      expect(request.params).to be_nil
      expect(request.notification?).to be_false
    end

    it "parses request with params" do
      json = %Q|{"jsonrpc": "2.0", "id": 1, "method": "test", "params": {"foo": "bar"}}|
      request = described_class.from_json(json)

      expect(request.jsonrpc).to eq("2.0")
      expect(request.id).to eq(1)
      expect(request.method).to eq("test")
      expect(request.params.try(&.as_h)).to eq({"foo" => "bar"})
      expect(request.notification?).to be_false
    end
  end

  describe "#to_json" do
    it "serializes request without params" do
      request = described_class.new("123", "test")
      json = request.to_json
      parsed = JSON.parse(json)

      expect(parsed["jsonrpc"]).to eq("2.0")
      expect(parsed["id"]).to eq("123")
      expect(parsed["method"]).to eq("test")
      expect(parsed["params"]?).to be_nil
    end

    it "serializes request with params" do
      params = JSON::Any.new({"foo" => JSON::Any.new("bar")})
      request = described_class.new(456, "test", params)
      json = request.to_json
      parsed = JSON.parse(json)

      expect(parsed["jsonrpc"]).to eq("2.0")
      expect(parsed["id"]).to eq(456)
      expect(parsed["method"]).to eq("test")
      expect(parsed["params"]["foo"]).to eq("bar")
    end
  end

  context "notifications" do
    describe ".from_json" do
      it "parses notification (without id)" do
        json = %Q|{"jsonrpc": "2.0", "method": "notification"}|
        request = described_class.from_json(json)

        expect(request.jsonrpc).to eq("2.0")
        expect(request.id).to be_nil
        expect(request.method).to eq("notification")
        expect(request.params).to be_nil
        expect(request.notification?).to be_true
      end

      it "parses notification with params" do
        json = %Q|{"jsonrpc": "2.0", "method": "notification", "params": [1, 2, 3]}|
        request = described_class.from_json(json)

        expect(request.jsonrpc).to eq("2.0")
        expect(request.id).to be_nil
        expect(request.method).to eq("notification")
        expect(request.params.try(&.as_a)).to eq([1, 2, 3])
        expect(request.notification?).to be_true
      end
    end

    describe "#to_json" do
      it "serializes notification without params" do
        request = described_class.new(nil, "test")
        json = request.to_json
        parsed = JSON.parse(json)

        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]?).to be_nil
        expect(parsed["method"]).to eq("test")
        expect(parsed["params"]?).to be_nil
      end

      it "serializes notification with params" do
        params = JSON::Any.new({"foo" => JSON::Any.new("bar")})
        request = described_class.new(nil, "test", params)
        json = request.to_json
        parsed = JSON.parse(json)

        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]?).to be_nil
        expect(parsed["method"]).to eq("test")
        expect(parsed["params"]["foo"]).to eq("bar")
      end
    end
  end
end

Spectator.describe JSON::RPC::Response do
  describe "success" do
    describe "#to_json" do
      it "serializes success response" do
        result = JSON::Any.new({"status" => JSON::Any.new("ok")})
        response = described_class.new("123", result)
        json = response.to_json
        parsed = JSON.parse(json)

        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]).to eq("123")
        expect(parsed["result"]["status"]).to eq("ok")
      end
    end

    describe ".from_json" do
      it "parses success response" do
        json = %Q|{"jsonrpc": "2.0", "id": 456, "result": {"data": "success"}}|
        response = described_class.from_json(json)

        expect(response.jsonrpc).to eq("2.0")
        expect(response.id).to eq(456)
        expect(response.result.not_nil!["data"]).to eq("success")
      end
    end
  end

  describe "error" do
    describe "#to_json" do
      it "serializes error response without data" do
        error = JSON::RPC::Response::Error.new(-32600, "Invalid Request")
        response = described_class.new("123", error: error)
        json = response.to_json
        parsed = JSON.parse(json)

        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]).to eq("123")
        expect(parsed["error"]["code"]).to eq(-32600)
        expect(parsed["error"]["message"]).to eq("Invalid Request")
        expect(parsed["error"]["data"]?).to be_nil
      end

      it "serializes error response with data" do
        error_data = JSON::Any.new({"details" => JSON::Any.new("More info")})
        error = JSON::RPC::Response::Error.new(-32603, "Internal error", error_data)
        response = described_class.new(789, error: error)
        json = response.to_json
        parsed = JSON.parse(json)

        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]).to eq(789)
        expect(parsed["error"]["code"]).to eq(-32603)
        expect(parsed["error"]["message"]).to eq("Internal error")
        expect(parsed["error"]["data"]["details"]).to eq("More info")
      end
    end

    describe ".from_json" do
      it "parses error response" do
        json = %Q|{"jsonrpc": "2.0", "id": 456, "error": {"code": -32601, "message": "Method not found"}}|
        response = described_class.from_json(json)

        expect(response.jsonrpc).to eq("2.0")
        expect(response.id).to eq(456)
        expect(response.error.not_nil!.code).to eq(-32601)
        expect(response.error.not_nil!.message).to eq("Method not found")
        expect(response.error.not_nil!.data).to be_nil
      end
    end
  end

  describe "validation" do
    it "raises error when both result and error are provided" do
      result = JSON::Any.new({"status" => JSON::Any.new("ok")})
      error = JSON::RPC::Response::Error.new(-32600, "Invalid Request")

      expect { described_class.new("test-id", result, error) }.
        to raise_error(ArgumentError, "Response cannot have both result and error")
    end

    it "raises error when neither result nor error are provided" do
      expect { described_class.new("test-id") }.
        to raise_error(ArgumentError, "Response must have either result or error")
    end
  end

  it "identifies success responses correctly" do
    result = JSON::Any.new({"status" => JSON::Any.new("ok")})
    success_response = described_class.new("test-id", result)

    expect(success_response.success?).to be_true
    expect(success_response.error?).to be_false
  end

  it "identifies error responses correctly" do
    error = JSON::RPC::Response::Error.new(-32600, "Invalid Request")
    error_response = described_class.new("test-id", error: error)

    expect(error_response.success?).to be_false
    expect(error_response.error?).to be_true
  end
end
