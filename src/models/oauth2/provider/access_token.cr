require "../../../framework/model"
require "../../../framework/model/**"
require "../../account"
require "./client"

module OAuth2
  module Provider
    class AccessToken
      include Ktistec::Model
      include Ktistec::Model::Common

      @@table_name = "oauth_access_tokens"

      # The access token string.
      #
      # This is a unique, randomly generated, and unguessable value
      # that the client application uses to authenticate its requests
      # to the server. The client sends this token in the
      # `Authorization` header of an API request.
      #
      @[Persistent]
      property token : String

      # The client application ID.
      #
      # Links the access token to the OAuth2 `Client` model. It
      # identifies *which application* this token was issued to.
      #
      @[Persistent]
      property client_id : Int64?
      belongs_to client

      # The account ID.
      #
      # Links the access token to the `Account` model. It identifies
      # *which user* the token represents.
      #
      @[Persistent]
      property account_id : Int64?
      belongs_to account

      # The expiration.
      #
      # A timestamp that indicates when the access token becomes invalid.
      #
      @[Persistent]
      property expires_at : Time

      # Scopes.
      #
      # Stores the specific permissions that the user granted when
      # they authorized the application.
      #
      @[Persistent]
      property scope : String
    end
  end
end
