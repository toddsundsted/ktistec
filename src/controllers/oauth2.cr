require "../framework/controller"
require "../models/oauth2/provider/client"
require "../models/oauth2/provider/access_token"
require "./oauth2/registration"

require "digest"
require "openssl"
require "random"

class OAuth2Controller
  include Ktistec::Controller

  skip_auth ["/oauth/token"], POST

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
      OAuth2::RegistrationController.provisional_clients.find do |client|
        client.client_id == client_id
      end
  end

  get "/oauth/authorize" do |env|
    state = env.params.query["state"]?.presence
    unless state
      bad_request "`state` is required"
    end

    code_challenge = env.params.query["code_challenge"]?.presence
    unless code_challenge
      bad_request "`code_challenge` is required"
    end

    code_challenge_method = env.params.query["code_challenge_method"]?.presence
    unless code_challenge_method == "S256"
      bad_request "Unsupported `code_challenge_method`"
    end

    client_id = env.params.query["client_id"]?.presence
    redirect_uri = env.params.query["redirect_uri"]?.presence
    unless client_id && redirect_uri
      bad_request "`client_id` and `redirect_uri` are required"
    end

    client = find_client(client_id)
    unless client
      bad_request "Invalid `client_id`"
    end

    unless client.redirect_uris.split.includes?(redirect_uri)
      bad_request "Invalid `redirect_uri`"
    end

    response_type = env.params.query["response_type"]?.presence
    unless response_type == "code"
      bad_request "Unsupported `response_type`"
    end

    scope = env.params.query["scope"]? || "all"

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
    state = env.params.body["state"]?.presence
    unless state
      bad_request "`state` is required"
    end

    code_challenge = env.params.body["code_challenge"]?.presence
    unless code_challenge
      bad_request "`code_challenge` is required"
    end

    code_challenge_method = env.params.body["code_challenge_method"]?.presence
    unless code_challenge_method && code_challenge_method == "S256"
      bad_request "Unsupported `code_challenge_method`"
    end

    client_id = env.params.body["client_id"]?.presence
    redirect_uri = env.params.body["redirect_uri"]?.presence
    unless client_id && redirect_uri
      bad_request "`client_id` and `redirect_uri` are required"
    end

    client = find_client(client_id)
    unless client
      bad_request "Invalid `client_id`"
    end

    unless client.redirect_uris.split.includes?(redirect_uri)
      bad_request "Invalid `redirect_uri`"
    end

    response_type = env.params.body["response_type"]?.presence
    unless response_type == "code"
      bad_request "Unsupported `response_type`"
    end

    # delete the provisional client no matter what
    OAuth2::RegistrationController.provisional_clients.delete(client)

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

  post "/oauth/token" do |env|
    grant_type = env.params.body["grant_type"]?.presence
    unless grant_type == "authorization_code"
      bad_request "Unsupported `grant_type`"
    end

    code = env.params.body["code"]?.presence
    unless code
      bad_request "`code` is required"
    end

    auth_code = @@authorization_codes.delete(code)
    unless auth_code
      bad_request "Invalid `code`"
    end
    if auth_code.expires_at < Time.utc
      bad_request "Expired `code`"
    end

    redirect_uri = env.params.body["redirect_uri"]?.presence
    unless redirect_uri && redirect_uri == auth_code.redirect_uri
      bad_request "Invalid `redirect_uri`"
    end

    code_verifier = env.params.body["code_verifier"]?.presence
    unless code_verifier
      bad_request "`code_verifier` is required"
    end

    code_challenge = Base64.urlsafe_encode(Digest::SHA256.digest(code_verifier), padding: false)
    unless code_challenge == auth_code.code_challenge
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
          unauthorized "Invalid client credentials"
        end
      else
        client_id = env.params.body["client_id"]?.presence
        unless client_id && client_id == auth_code.client_id
          bad_request "Invalid `client_id`"
        end

        client_secret = env.params.body["client_secret"]?.presence

        c = OAuth2::Provider::Client.find?(client_id: client_id)
        if client_secret && c && client_secret == c.client_secret
          c
        else
          unauthorized "Invalid `client_secret`"
        end
      end

    access_token = OAuth2::Provider::AccessToken.new(
      token: Random::Secure.urlsafe_base64,
      client_id: client.id,
      account_id: auth_code.account_id,
      expires_at: Time.utc + 1.hour,
      scope: "all",
    ).save

    env.response.content_type = "application/json"
    env.response.print({
      access_token: access_token.token,
      token_type: "Bearer",
      expires_in: 3600,
      scope: access_token.scope
    }.to_json)
  end
end
