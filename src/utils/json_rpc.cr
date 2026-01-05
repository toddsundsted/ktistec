require "json"

module JSON::RPC
  VERSION = "2.0"

  # Represents a JSON-RPC request or notification.
  #
  # A request has an `id` and expects a response, while a notification
  # has no `id`.
  #
  struct Request
    include JSON::Serializable

    property jsonrpc : String = VERSION

    property id : String | Int32 | Nil

    property method : String

    property params : JSON::Any?

    def initialize(@id, @method, @params = nil)
    end

    def notification?
      @id.nil?
    end
  end

  # Represents a JSON-RPC response containing either a result or an error.
  #
  # Exactly one of `result` or `error` must be present.
  #
  struct Response
    include JSON::Serializable

    property jsonrpc : String = VERSION

    property id : String | Int32

    property result : JSON::Any?

    property error : Error?

    def initialize(@id, @result : JSON::Any? = nil, @error : Error? = nil)
      if @result && @error
        raise ArgumentError.new("Response cannot have both result and error")
      end
      if !@result && !@error
        raise ArgumentError.new("Response must have either result or error")
      end
    end

    def success?
      !@result.nil?
    end

    def error?
      !@error.nil?
    end

    # Represents a JSON-RPC error.
    #
    struct Error
      include JSON::Serializable

      property code : Int32

      property message : String

      property data : JSON::Any?

      def initialize(@code, @message, @data = nil)
      end
    end
  end

  # Standard JSON-RPC 2.0 error codes.
  #
  module ErrorCodes
    PARSE_ERROR      = -32700
    INVALID_REQUEST  = -32600
    METHOD_NOT_FOUND = -32601
    INVALID_PARAMS   = -32602
    INTERNAL_ERROR   = -32603
  end
end
