require "../../../framework/model"
require "../../../framework/model/**"
require "./access_token"

module OAuth2
  module Provider
    class Client
      include Ktistec::Model
      include Ktistec::Model::Common

      @@table_name = "oauth_clients"

      # Public identifier for a third-party application.
      #
      # When an application wants to request access to a user's
      # account, it sends this ID to identify itself. It is not a
      # secret.
      #
      @[Persistent]
      property client_id : String

      # Client secret.
      #
      # This is a confidential secret known only to the application
      # and the Ktistec server. It's used clients to authenticate
      # themselves when they exchange an authorization code for an
      # access token. This proves that the request is coming from the
      # legitimate application.
      #
      @[Persistent]
      property client_secret : String

      # A human-readable name for the application.
      #
      # The name is shown to the user on the consent screen so they
      # know which application is asking for permission.
      #
      @[Persistent]
      property client_name : String

      # A list of redirect URIs.
      #
      # This is a critical security feature. It is a list of one or
      # more URIs that the Ktistec server is allowed to redirect the
      # user back to after they have authorized the application. The
      # `redirect_uri` sent in the authorization request *must* be one
      # of the URLs in this list.
      #
      @[Persistent]
      property redirect_uris : String

      # Scopes.
      #
      # Defines the specific permissions the application is requesting
      # (e.g., `read`, `write`). The user will see these requested
      # scopes on the consent screen and must approve them. The
      # resulting access token will be limited to these permissions.
      #
      @[Persistent]
      property scope : String

      # Last accessed timestamp.
      #
      # Records when this client last accessed the server (when it
      # exchanged an authorization code for an access token). Used for
      # tracking client activity and identifying unused clients.
      #
      @[Persistent]
      @[Insignificant]
      property last_accessed_at : Time?

      has_many access_tokens
    end
  end
end
