require "../../models/oauth2/provider/client"

module OAuth2
  # Shared service for OAuth client registration.
  #
  # Supports provisional storage where clients are only persisted to
  # the database after first authorization.
  #
  class ClientRegistration
    # out-of-band redirect uri
    OOB_REDIRECT_URI = "urn:ietf:wg:oauth:2.0:oob"

    record Success, client : Provider::Client
    record Failure, error : String
    alias Result = Success | Failure

    # provisional ring buffer for newly registered clients
    @@provisional_clients = Deque(Provider::Client).new

    class_property buffer_size : Int32 = 20

    # Returns the provisional clients buffer.
    #
    # For testing.
    #
    def self.provisional_clients
      @@provisional_clients
    end

    # Registers a new OAuth client.
    #
    # Validates input, creates a new client instance, and stores it
    # in the provisional buffer. The client is not persisted to the
    # database until `persist` is called.
    #
    def self.register(
      client_name : String,
      redirect_uris : Array(String),
      scopes : String = "read",
    ) : Result
      unless client_name.presence
        return Failure.new("`client_name` is required")
      end
      if redirect_uris.empty?
        return Failure.new("`redirect_uris` is required")
      end
      invalid_uris = validate_redirect_uris(redirect_uris)
      unless invalid_uris.empty?
        return Failure.new("`redirect_uris` contains invalid URIs: #{invalid_uris.join(", ")}")
      end

      client = Provider::Client.new(
        client_id: Random::Secure.urlsafe_base64,
        client_secret: Random::Secure.urlsafe_base64,
        client_name: client_name,
        redirect_uris: redirect_uris.join(" "),
        scope: scopes
      )

      @@provisional_clients.push(client)
      if @@provisional_clients.size > @@buffer_size
        @@provisional_clients.shift
      end

      Success.new(client)
    end

    # Validates redirect URIs.
    #
    # Returns an array of **invalid URIs** (empty if all are valid).
    #
    private def self.validate_redirect_uris(uris : Array(String)) : Array(String)
      uris.compact_map do |uri_string|
        next if uri_string == OOB_REDIRECT_URI
        begin
          uri = URI.parse(uri_string)
          unless uri.scheme.presence && uri.host.presence
            uri_string
          end
        rescue URI::Error
          uri_string
        end
      end
    end

    # Finds client by `client_id`.
    #
    def self.find(client_id : String) : Provider::Client?
      Provider::Client.find?(client_id: client_id) ||
        @@provisional_clients.find do |client|
          client.client_id == client_id
        end
    end

    # Persists client to database.
    #
    # Removes the client from the provisional buffer and saves it
    # to the database if it's a new record.
    #
    def self.persist(client : Provider::Client) : Provider::Client
      @@provisional_clients.delete(client)
      client.save if client.new_record?
      client
    end

    # Removes client from provisional storage without persisting.
    #
    def self.remove_provisional(client : Provider::Client) : Nil
      @@provisional_clients.delete(client)
    end
  end
end
