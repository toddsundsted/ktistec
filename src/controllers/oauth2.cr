require "../framework/controller"
require "../services/oauth2/client_registration"
require "../models/oauth2/provider/client"
require "../models/oauth2/provider/access_token"

require "digest"
require "openssl"
require "random"

class OAuth2Controller
  include Ktistec::Controller

  Log = ::Log.for("oauth2")

  skip_auth ["/oauth/register", "/oauth/token"], OPTIONS, POST

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
    set_headers

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

    client_name = client_name_raw.try(&.as_s) || ""

    redirect_uris = [] of String
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

    result = OAuth2::ClientRegistration.register(
      client_name: client_name,
      redirect_uris: redirect_uris,
      scopes: "mcp",
    )

    case result
    in OAuth2::ClientRegistration::Success
      client = result.client
      env.response.status_code = 201
      {
        "client_id"     => client.client_id,
        "client_secret" => client.client_secret,
        "client_name"   => client.client_name,
        "redirect_uris" => client.redirect_uris.split,
      }.to_json
    in OAuth2::ClientRegistration::Failure
      Log.debug { result.error }
      bad_request result.error
    end
  end

  record AuthorizationCode,
    account_id : Int64,
    client_id : String,
    redirect_uri : String,
    code_challenge : String?,
    code_challenge_method : String?,
    expires_at : Time,
    scope : String

  class_property authorization_codes = {} of String => AuthorizationCode

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
    code_challenge_method = env.params.query["code_challenge_method"]?.presence

    # PKCE is optional, but if code_challenge is provided, method must be S256
    if code_challenge && code_challenge_method != "S256"
      Log.debug { "Unsupported `code_challenge_method`: #{code_challenge_method}" }
      bad_request "Unsupported `code_challenge_method`"
    end

    unless client_id && redirect_uri
      Log.debug { "`client_id` and `redirect_uri` are required" }
      bad_request "`client_id` and `redirect_uri` are required"
    end

    client = OAuth2::ClientRegistration.find(client_id)
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
    scope = env.params.body["scope"]? || "mcp"

    Log.trace do
      "authorize[POST]: " \
      "client_id=#{client_id}, " \
      "redirect_uri=#{redirect_uri}, " \
      "response_type=#{response_type}, " \
      "state_present=#{!!state}"
    end

    code_challenge = env.params.body["code_challenge"]?.presence
    code_challenge_method = env.params.body["code_challenge_method"]?.presence

    # PKCE is optional, but if code_challenge is provided, method must be S256
    if code_challenge && code_challenge_method != "S256"
      Log.debug { "Unsupported `code_challenge_method`: #{code_challenge_method}" }
      bad_request "Unsupported `code_challenge_method`"
    end

    unless client_id && redirect_uri
      Log.debug { "`client_id` and `redirect_uri` are required" }
      bad_request "`client_id` and `redirect_uri` are required"
    end

    client = OAuth2::ClientRegistration.find(client_id)
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

    if env.params.body["deny"]?
      OAuth2::ClientRegistration.remove_provisional(client)
      redirect_uri = URI.parse(redirect_uri)
      redirect_uri.query = "error=access_denied&state=#{state}"
    else
      OAuth2::ClientRegistration.persist(client)

      # in-memory storage for the authorization code

      code = Random::Secure.urlsafe_base64

      @@authorization_codes[code] = AuthorizationCode.new(
        account_id: env.account.id.not_nil!,
        client_id: client.client_id,
        redirect_uri: redirect_uri,
        code_challenge: code_challenge,
        code_challenge_method: code_challenge_method,
        expires_at: Time.utc + 10.minutes,
        scope: scope,
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
    set_headers

    params =
      begin
        env.params.body.presence || env.params.json.presence
      rescue JSON::ParseException
        Log.debug { "Invalid JSON body" }
        bad_request "Invalid JSON"
      end

    if params
      grant_type = params["grant_type"]?.try(&.to_s).presence
      code = params["code"]?.try(&.to_s).presence
      redirect_uri = params["redirect_uri"]?.try(&.to_s).presence
      code_verifier = params["code_verifier"]?.try(&.to_s).presence
      client_id = params["client_id"]?.try(&.to_s).presence
      client_secret = params["client_secret"]?.try(&.to_s).presence
      auth_header = env.request.headers["Authorization"]?.presence
    end

    Log.trace do
      "token[POST]: " \
      "grant_type=#{grant_type}, " \
      "code_present=#{!!code}, " \
      "redirect_uri=#{redirect_uri}, " \
      "code_verifier_present=#{!!code_verifier}, " \
      "client_id=#{client_id}, " \
      "auth_basic=#{auth_header && auth_header.starts_with?("Basic ")}"
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

    # PKCE verification is only required if code_challenge was provided during authorization
    if auth_code.code_challenge
      unless code_verifier
        Log.debug { "`code_verifier` is required" }
        bad_request "`code_verifier` is required"
      end

      computed_challenge = Base64.urlsafe_encode(Digest::SHA256.digest(code_verifier), padding: false)
      unless computed_challenge == auth_code.code_challenge
        Log.debug { "Invalid `code_verifier`" }
        bad_request "Invalid `code_verifier`"
      end
    end

    client_id_param = client_id
    client_secret_param = client_secret

    client =
      if (auth = env.request.headers["Authorization"]?) && auth.starts_with?("Basic ")
        credentials = Base64.decode_string(auth[6..-1])
        client_id, client_secret = credentials.split(':', 2)
        c = OAuth2::Provider::Client.find?(client_id: client_id)
        unless c && client_secret == c.client_secret
          Log.debug { "Invalid client credentials" }
          unauthorized "Invalid client credentials"
        end
        c
      else
        client_id = client_id_param
        unless client_id && client_id == auth_code.client_id
          Log.debug { "Invalid `client_id`" }
          bad_request "Invalid `client_id`"
        end
        c = OAuth2::Provider::Client.find?(client_id: client_id)
        unless c
          Log.debug { "Invalid `client_id`" }
          bad_request "Invalid `client_id`"
        end
        # require client authentication: either `client_secret` (any
        # client that registered with one) or a PKCE-protected auth
        # code (the verifier was already validated against
        # `code_challenge` above). `client_id` alone is not a secret.
        unless client_secret_param || auth_code.code_challenge
          Log.debug { "Client authentication required" }
          unauthorized "Client authentication required"
        end
        if client_secret_param
          unless client_secret_param == c.client_secret
            Log.debug { "Invalid `client_secret`" }
            unauthorized "Invalid `client_secret`"
          end
        end
        c
      end

    # track client activity
    client.assign(last_accessed_at: Time.utc).save

    access_token = OAuth2::Provider::AccessToken.new(
      token: Random::Secure.urlsafe_base64,
      client_id: client.id,
      account_id: auth_code.account_id,
      expires_at: Time.utc + OAuth2::Provider::AccessToken::TTL,
      scope: auth_code.scope,
    ).save

    {
      token_type:   "Bearer",
      access_token: access_token.token,
      scope:        access_token.scope,
      created_at:   access_token.created_at.to_unix,
      expires_in:   OAuth2::Provider::AccessToken::TTL.to_i,
    }.to_json
  end
end
