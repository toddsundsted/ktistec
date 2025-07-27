require "../../framework/controller"
require "../../models/oauth2/provider/client"

require "random"

module OAuth2
  class RegistrationController
    include Ktistec::Controller

    skip_auth ["/oauth/register"], POST

    # In-memory provisional ring buffer for newly registered clients.
    #
    # A client is only persisted to the database after it has been
    # successfully used in the first step of an authorization flow.
    #
    class_property provisional_clients = Deque(OAuth2::Provider::Client).new

    # Size of the in-memory provisional storage ring buffer.
    #
    class_property provisional_client_buffer_size = 20

    post "/oauth/register" do |env|
      body = env.request.body.not_nil!
      begin
        json = JSON.parse(body)
      rescue JSON::ParseException
        bad_request "Invalid JSON"
      end

      client_name_raw = json["client_name"]?
      redirect_uris_raw = json["redirect_uris"]?

      unless (client_name = client_name_raw.try(&.as_s).presence)
        bad_request "`client_name` is required"
      end

      if redirect_uris_raw
        if (redirect_uris_as_string = redirect_uris_raw.as_s?)
          redirect_uris = [redirect_uris_as_string]
        elsif (redirect_uris_as_array = redirect_uris_raw.as_a?)
          redirect_uris = redirect_uris_as_array.map(&.as_s)
        else
          bad_request "`redirect_uris` must be a string or array of strings"
        end
      end
      unless redirect_uris
        bad_request "`redirect_uris` is required"
      end

      error = nil
      redirect_uris.each do |uri_string|
        begin
          uri = URI.parse(uri_string)
          unless uri.scheme == "https"
            error = "all `redirect_uris` must use https"
            break
          end
        rescue URI::Error
          error = "`redirect_uris` must be valid URIs"
          break
        end
      end
      if error
        bad_request error
      end

      client = OAuth2::Provider::Client.new(
        client_id: Random::Secure.urlsafe_base64,
        client_secret: Random::Secure.urlsafe_base64,
        redirect_uris: redirect_uris.join(" "),
        client_name: client_name,
        scope: "all"
      )

      @@provisional_clients.push(client)
      if @@provisional_clients.size > @@provisional_client_buffer_size
        @@provisional_clients.shift
      end

      env.response.status_code = 201
      env.response.content_type = "application/json"
      env.response.print({
        "client_id" => client.client_id,
        "client_secret" => client.client_secret,
        "client_name" => client.client_name,
        "redirect_uris" => client.redirect_uris,
      }.to_json)
    end
  end
end
