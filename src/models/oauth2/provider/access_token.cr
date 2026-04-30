require "../../../framework/model"
require "../../../framework/model/**"
require "../../account"
require "../../session"
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

      # The session.
      #
      # Links to the `Session` if one exists for this access token.
      #
      has_one :session, foreign_key: oauth_access_token_id, inverse_of: oauth_access_token

      # The expiration.
      #
      # A timestamp that indicates when the access token becomes invalid.
      #
      @[Persistent]
      @[Insignificant]
      property expires_at : Time

      # Scopes.
      #
      # Stores the specific permissions that the user granted when
      # they authorized the application.
      #
      @[Persistent]
      property scope : String

      # The lifetime granted to a token at issue or renewal.
      #
      TTL = 30.days

      # Renew once more than 1/8th of the TTL has elapsed since the
      # last renewal.
      #
      RENEWAL_THRESHOLD = TTL * 7 / 8

      # Finds an access token given its token string.
      #
      def self.find_by_token?(token : String)
        find?(token: token)
      end

      # Checks if the access token is expired.
      #
      def expired?
        Time.utc > expires_at
      end

      # Slides the expiration forward when the token is used.
      #
      # No-op for expired tokens and for tokens still within the
      # renewal threshold.
      #
      def touch
        return self if expired?
        if (expires_at - Time.utc) < RENEWAL_THRESHOLD
          new_expires_at = Time.utc + TTL
          rows_affected = self.class.exec(
            "UPDATE #{table_name} SET expires_at = ? WHERE id = ?",
            new_expires_at, id!,
          )
          self.expires_at = new_expires_at if rows_affected > 0
        end
        self
      end

      # Checks if the access token has "mcp" scope.
      #
      def has_mcp_scope?
        scope.split.includes?("mcp")
      end
    end
  end
end
