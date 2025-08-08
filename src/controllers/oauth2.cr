require "../framework/controller"
require "../models/oauth2/provider/client"
require "../models/oauth2/provider/access_token"

require "digest"
require "openssl"
require "random"

class OAuth2Controller
  include Ktistec::Controller

  Log = ::Log.for(self)

  skip_auth ["/oauth/register", "/oauth/token"], OPTIONS, POST

  # In-memory provisional ring buffer for newly registered clients.
  #
  # A client is only persisted to the database after it has been
  # successfully used in the first step of an authorization flow.
  #
  class_property provisional_clients = Deque(OAuth2::Provider::Client).new

  # Size of the in-memory provisional storage ring buffer.
  #
  class_property provisional_client_buffer_size = 20

  private macro set_headers
    env.response.headers.add("Access-Control-Allow-Origin", "*")
    env.response.headers.add("Access-Control-Allow-Methods", "POST, OPTIONS")
    env.response.headers.add("Access-Control-Allow-Headers", "Authorization, Content-Type, MCP-Protocol-Version")
    env.response.content_type = "application/json"
  end

  options "/oauth/register" do |env|
    set_headers
    no_content
  end

  post "/oauth/register" do |env|
    body = env.request.body.not_nil!
    begin
      json = JSON.parse(body)
    rescue JSON::ParseException
      Log.debug { "Invalid JSON" }
      bad_request "Invalid JSON"
    end

    client_name_raw = json["client_name"]?
    redirect_uris_raw = json["redirect_uris"]?

    Log.trace { "register[POST]: client_name=#{client_name_raw}, redirect_uris=#{redirect_uris_raw}" }

    unless (client_name = client_name_raw.try(&.as_s).presence)
      Log.debug { "`client_name` is required" }
      bad_request "`client_name` is required"
    end

    if redirect_uris_raw
      if (redirect_uris_as_string = redirect_uris_raw.as_s?)
        redirect_uris = [redirect_uris_as_string]
      elsif (redirect_uris_as_array = redirect_uris_raw.as_a?)
        redirect_uris = redirect_uris_as_array.map(&.as_s)
      else
        Log.debug { "`redirect_uris` must be a string or array of strings" }
        bad_request "`redirect_uris` must be a string or array of strings"
      end
    end
    unless redirect_uris
      Log.debug { "`redirect_uris` is required" }
      bad_request "`redirect_uris` is required"
    end

    errors = [] of String
    redirect_uris.each do |uri_string|
      begin
        uri = URI.parse(uri_string)
        unless uri.scheme.presence && uri.host.presence
          errors << uri_string
        end
      rescue URI::Error
        errors << uri_string
      end
    end
    unless errors.empty?
      Log.debug { "`redirect_uris` must be valid URIs: #{errors.join(", ")}" }
      bad_request "`redirect_uris` must be valid URIs"
    end

    client = OAuth2::Provider::Client.new(
      client_id: Random::Secure.urlsafe_base64,
      client_secret: Random::Secure.urlsafe_base64,
      client_name: client_name,
      redirect_uris: redirect_uris.join(" "),
      scope: "mcp"
    )

    @@provisional_clients.push(client)
    if @@provisional_clients.size > @@provisional_client_buffer_size
      @@provisional_clients.shift
    end

    set_headers
    env.response.status_code = 201

    {
      "client_id" => client.client_id,
      "client_secret" => client.client_secret,
      "client_name" => client.client_name,
      "redirect_uris" => client.redirect_uris.split,
    }.to_json
  end

  record AuthorizationCode,
    account_id : Int64,
    client_id : String,
    redirect_uri : String,
    code_challenge : String,
    code_challenge_method : String,
    expires_at : Time

  class_property authorization_codes = {} of String => AuthorizationCode

  private def self.find_client(client_id)
    OAuth2::Provider::Client.find?(client_id: client_id) ||
      @@provisional_clients.find do |client|
        client.client_id == client_id
      end
  end

  get "/oauth/authorize" do |env|
    client_id = env.params.query["client_id"]?.presence
    redirect_uri = env.params.query["redirect_uri"]?.presence
    response_type = env.params.query["response_type"]?.presence
    state = env.params.query["state"]?.presence
    scope = env.params.query["scope"]? || "mcp"

    Log.trace do
      "authorize[GET]: " \
      "client_id=#{client_id}, " \
      "redirect_uri=#{redirect_uri}, " \
      "response_type=#{response_type}, " \
      "state_present=#{!!state}, " \
      "scope=#{scope}"
    end

    code_challenge = env.params.query["code_challenge"]?.presence
    unless code_challenge
      Log.debug { "`code_challenge` is required" }
      bad_request "`code_challenge` is required"
    end

    code_challenge_method = env.params.query["code_challenge_method"]?.presence
    unless code_challenge_method == "S256"
      Log.debug { "Unsupported `code_challenge_method`: #{code_challenge_method}" }
      bad_request "Unsupported `code_challenge_method`"
    end

    unless client_id && redirect_uri
      Log.debug { "`client_id` and `redirect_uri` are required" }
      bad_request "`client_id` and `redirect_uri` are required"
    end

    client = find_client(client_id)
    unless client
      Log.debug { "Invalid `client_id`: #{client_id}" }
      bad_request "Invalid `client_id`"
    end

    unless client.redirect_uris.split.includes?(redirect_uri)
      Log.debug { "Invalid `redirect_uri`: #{redirect_uri}" }
      bad_request "Invalid `redirect_uri`"
    end

    unless response_type == "code"
      Log.debug { "Unsupported `response_type`: #{response_type}" }
      bad_request "Unsupported `response_type`"
    end

    ok "oauth/authorize",
      env: env,
      state: state,
      code_challenge: code_challenge,
      code_challenge_method: code_challenge_method,
      client: client,
      redirect_uri: redirect_uri,
      response_type: response_type,
      scope: scope
  end

  post "/oauth/authorize" do |env|
    client_id = env.params.body["client_id"]?.presence
    redirect_uri = env.params.body["redirect_uri"]?.presence
    response_type = env.params.body["response_type"]?.presence
    state = env.params.body["state"]?.presence

    Log.trace do
      "authorize[POST]: " \
      "client_id=#{client_id}, " \
      "redirect_uri=#{redirect_uri}, " \
      "response_type=#{response_type}, " \
      "state_present=#{!!state}"
    end

    code_challenge = env.params.body["code_challenge"]?.presence
    unless code_challenge
      Log.debug { "`code_challenge` is required" }
      bad_request "`code_challenge` is required"
    end

    code_challenge_method = env.params.body["code_challenge_method"]?.presence
    unless code_challenge_method && code_challenge_method == "S256"
      Log.debug { "Unsupported `code_challenge_method`: #{code_challenge_method}" }
      bad_request "Unsupported `code_challenge_method`"
    end

    unless client_id && redirect_uri
      Log.debug { "`client_id` and `redirect_uri` are required" }
      bad_request "`client_id` and `redirect_uri` are required"
    end

    client = find_client(client_id)
    unless client
      Log.debug { "Invalid `client_id`: #{client_id}" }
      bad_request "Invalid `client_id`"
    end

    unless client.redirect_uris.split.includes?(redirect_uri)
      Log.debug { "Invalid `redirect_uri`: #{redirect_uri}" }
      bad_request "Invalid `redirect_uri`"
    end

    unless response_type == "code"
      Log.debug { "Unsupported `response_type`: #{response_type}" }
      bad_request "Unsupported `response_type`"
    end

    # delete the provisional client no matter what
    @@provisional_clients.delete(client)

    if env.params.body["deny"]?
      redirect_uri = URI.parse(redirect_uri)
      redirect_uri.query = "error=access_denied&state=#{state}"
    else
      client.save if client.new_record?

      # in-memory storage for the authorization code

      code = Random::Secure.urlsafe_base64

      @@authorization_codes[code] = AuthorizationCode.new(
        account_id: env.account.id.not_nil!,
        client_id: client.client_id,
        redirect_uri: redirect_uri,
        code_challenge: code_challenge,
        code_challenge_method: code_challenge_method,
        expires_at: Time.utc + 10.minutes
      )

      redirect_uri = URI.parse(redirect_uri)
      redirect_uri.query = "code=#{code}&state=#{state}"
     end

    env.response.redirect redirect_uri.to_s
  end

  options "/oauth/token" do |env|
    set_headers
    no_content
  end

  post "/oauth/token" do |env|
    grant_type = env.params.body["grant_type"]?.presence
    code = env.params.body["code"]?.presence
    redirect_uri = env.params.body["redirect_uri"]?.presence
    code_verifier = env.params.body["code_verifier"]?.presence
    auth_header = env.request.headers["Authorization"]?.presence
    client_id_param = env.params.body["client_id"]?.presence

    Log.trace do
      "token[POST]: " \
      "grant_type=#{grant_type}, " \
      "code_present=#{!!code}, " \
      "redirect_uri=#{redirect_uri}, " \
      "code_verifier_present=#{!!code_verifier}, " \
      "auth_basic=#{auth_header && auth_header.starts_with?("Basic ")}, " \
      "client_id_param=#{client_id_param}"
    end

    unless grant_type == "authorization_code"
      Log.debug { "Unsupported `grant_type`: #{grant_type}" }
      bad_request "Unsupported `grant_type`"
    end

    unless code
      Log.debug { "`code` is required" }
      bad_request "`code` is required"
    end

    auth_code = @@authorization_codes.delete(code)
    unless auth_code
      Log.debug { "Invalid `code`" }
      bad_request "Invalid `code`"
    end
    if auth_code.expires_at < Time.utc
      Log.debug { "Expired `code`" }
      bad_request "Expired `code`"
    end

    unless redirect_uri && redirect_uri == auth_code.redirect_uri
      Log.debug { "Invalid `redirect_uri`: provided=#{redirect_uri} expected=#{auth_code.redirect_uri}" }
      bad_request "Invalid `redirect_uri`"
    end

    unless code_verifier
      Log.debug { "`code_verifier` is required" }
      bad_request "`code_verifier` is required"
    end

    code_challenge = Base64.urlsafe_encode(Digest::SHA256.digest(code_verifier), padding: false)
    unless code_challenge == auth_code.code_challenge
      Log.debug { "Invalid `code_verifier`" }
      bad_request "Invalid `code_verifier`"
    end

    client =
      if (auth = env.request.headers["Authorization"]?) && auth.starts_with?("Basic ")
        credentials = Base64.decode_string(auth[6..-1])
        client_id, client_secret = credentials.split(':', 2)

        c = OAuth2::Provider::Client.find?(client_id: client_id)
        if c && client_secret == c.client_secret
          c
        else
          Log.debug { "Invalid client credentials" }
          unauthorized "Invalid client credentials"
        end
      else
        client_id = client_id_param
        unless client_id && client_id == auth_code.client_id
          Log.debug { "Invalid `client_id`" }
          bad_request "Invalid `client_id`"
        end

        client_secret = env.params.body["client_secret"]?.presence

        c = OAuth2::Provider::Client.find?(client_id: client_id)
        if client_secret && c && client_secret == c.client_secret
          c
        else
          Log.debug { "Invalid `client_secret`" }
          unauthorized "Invalid `client_secret`"
        end
      end

    # track client activity
    client.assign(last_accessed_at: Time.utc).save

    access_token = OAuth2::Provider::AccessToken.new(
      token: Random::Secure.urlsafe_base64,
      client_id: client.id,
      account_id: auth_code.account_id,
      expires_at: Time.utc + 1.day,
      scope: "mcp",
    ).save

    set_headers

    {
      token_type: "Bearer",
      access_token: access_token.token,
      expires_in: 1.day.to_i,
      scope: access_token.scope,
    }.to_json
  end
end
