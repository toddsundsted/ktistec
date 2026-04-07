require "json"

require "../../models/oauth2/provider/client"

module API
  module V1::Serializers
    # Serializes an OAuth2 client to Mastodon Application JSON format.
    #
    # See: https://docs.joinmastodon.org/entities/Application/
    #
    struct Application
      include JSON::Serializable

      property id : String
      property name : String

      @[JSON::Field(emit_null: true)]
      property website : String?

      property scopes : Array(String)
      property redirect_uri : String
      property redirect_uris : Array(String)

      @[JSON::Field(emit_null: true)]
      property client_id : String?

      @[JSON::Field(emit_null: true)]
      property client_secret : String?

      @[JSON::Field(emit_null: true)]
      property client_secret_expires_at : Int32?

      @[JSON::Field(emit_null: true)]
      property vapid_key : String?

      def initialize(
        @id : String,
        @name : String,
        @website : String?,
        @scopes : Array(String),
        @redirect_uri : String,
        @redirect_uris : Array(String),
        @client_id : String?,
        @client_secret : String?,
        @client_secret_expires_at : Int32?,
        @vapid_key : String?,
      )
      end

      # Creates an Application from an OAuth2 Provider Client.
      #
      # When `include_secret` is true (default), includes client_secret
      # and related fields.
      #
      def self.from_client(
        client : OAuth2::Provider::Client,
        include_secret : Bool = true,
        website : String? = nil,
      ) : Application
        id = client.new_record? ? client.client_id : client.id.to_s

        redirect_uri = client.redirect_uris.split.join("\n")

        if include_secret
          Application.new(
            id: id,
            name: client.client_name,
            website: website,
            scopes: client.scope.split,
            redirect_uri: redirect_uri,
            redirect_uris: client.redirect_uris.split,
            client_id: client.client_id,
            client_secret: client.client_secret,
            client_secret_expires_at: 0,
            vapid_key: "",
          )
        else
          Application.new(
            id: id,
            name: client.client_name,
            website: website,
            scopes: client.scope.split,
            redirect_uri: redirect_uri,
            redirect_uris: client.redirect_uris.split,
            client_id: client.client_id,
            client_secret: nil,
            client_secret_expires_at: nil,
            vapid_key: nil,
          )
        end
      end
    end
  end
end
