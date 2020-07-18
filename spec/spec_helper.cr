require "spectator"
require "kemal"
require "json"
require "yaml"
require "xml"

# from https://github.com/kemalcr/spec-kemal/blob/master/src/spec-kemal.cr
# run specs with `KEMAL_ENV=test crystal spec`

class Global
  class_property response : HTTP::Client::Response?
  class_property account : Account?
  class_property session : Session?
end

class DummyAuth < Kemal::Handler
  def call(env)
    if (session = Global.session) && (account = Global.account)
      env.current_account = account
      env.session = session
    end
    return call_next(env)
  end
end

{% for method in %w(get post put head delete patch) %}
  def {{method.id}}(path, headers : HTTP::Headers? = nil, body : String? = nil)
    request = HTTP::Request.new("{{method.id}}".upcase, path, headers, body )
    Global.response = process_request request
  end
{% end %}

def process_request(request)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  main_handler = build_main_handler
  main_handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: false)
end

def build_main_handler
  main_handler = Kemal.config.handlers.first
  current_handler = main_handler
  Kemal.config.handlers.each do |handler|
    if handler.is_a?(Balloon::Auth) && Global.session && Global.account
      # if we "sign_in" in a context, swap in the dummy handler
      handler = DummyAuth.new
    end
    current_handler.next = handler
    current_handler = handler
  end
  main_handler
end

def response
  Global.response.not_nil!
end

def self.random_string
  ('a'..'z').to_a.shuffle.first(8).join + "1="
end

def self.register(username = random_string, password = random_string, *, with_keys = false)
  pem_public_key, pem_private_key =
    if with_keys
      keypair = OpenSSL::RSA.generate(2048, 17)
      {keypair.public_key.to_pem, keypair.to_pem}
    else
      {nil, nil}
    end
  Account.new(
    actor: ActivityPub::Actor.new(iri: "https://test.test/actors/#{username}", username: username, pem_public_key: pem_public_key, pem_private_key: pem_private_key),
    username: username,
    password: password
  ).save
end

def self._sign_in(username = nil)
  Global.account = account = username ? Account.find(username: username) : register
  Global.session = Session.new(account).save
end

def self._sign_out
  Global.account = nil
  Global.session = nil
end

macro sign_in(as username = nil)
  before_each { _sign_in({{username}}) }
  after_each { _sign_out }
end

# Networking mock.
#
# Cache an actor for later retrieval from the mock:
# `HTTP::Client.actors << ActivityPub::Actor.new(...`
#
# Fetch the last request sent to the mock:
# `Http::Client.last`
#
# Match the last request as a string:
# `expect(...last).to match("GET /foo/bar")`
#
class HTTP::Client
  @@last : HTTP::Request? = nil
  @@activities = [] of ActivityPub::Activity
  @@actors = [] of ActivityPub::Actor

  def self.last
    @@last
  end

  def self.activities
    @@activities
  end

  def self.actors
    @@actors
  end

  def self.reset
    @@last = nil
    @@activities.clear
    @@actors.clear
  end

  def self.get(url : String, headers : HTTP::Headers)
    @@last = HTTP::Request.new("GET", url, headers)
    url = URI.parse(url)
    case url.path
    when /bad-json/
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers.new,
        body: "bad json"
      )
    when /specified-page/
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers.new,
        body: "content"
      )
    when /redirected-page/
      HTTP::Client::Response.new(
        301,
        headers: HTTP::Headers{"Location" => "https://#{url.host}/specified-page"},
        body: ""
      )
    when /returns-([0-9]{3})/
      HTTP::Client::Response.new(
        $1.to_i,
        headers: HTTP::Headers.new,
        body: $1
      )
    when /activities\/([^\/]+)/
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers.new,
        body: (activity = @@activities.find { |a| a.iri == url.to_s }) ?
          activity.to_json_ld :
          <<-JSON
          {
            "@context":[
              "https://www.w3.org/ns/activitystreams"
            ],
            "type":"Activity",
            "id":"https://#{url.host}/#{$1}"
          }
          JSON
      )
    when /actors\/([^\/]+)/
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers.new,
        body: (actor = @@actors.find { |a| a.iri == url.to_s }) ?
          actor.to_json_ld :
          <<-JSON
          {
            "@context":[
              "https://www.w3.org/ns/activitystreams"
            ],
            "type":"Person",
            "id":"https://#{url.host}/#{$1}",
            "preferredUsername":"#{$1}"
          }
          JSON
      )
    else
      raise "not supported"
    end
  end
end

class String
  def ===(other : HTTP::Request)
    method, resource = self.split
    other.method == method && other.resource == resource
  end
end

require "../src/framework"

module Balloon
  class SpecConfig
    def db_file
      @db_file ||= "sqlite3://#{File.tempname("balloon-test", ".db")}"
    end
  end

  def self.config
    @@spec_config ||= SpecConfig.new
  end

  def self.clear_host
    Balloon.database.exec("DELETE FROM options WHERE key = ?", "host")
    @@host = nil
  end
end

class Account
  private def cost
    4 # reduce the cost of computing a bcrypt hash
  end
end

Balloon::Server.run do
  Balloon.host = "https://test.test"
  Kemal.config.port = Random.new.rand(49152..65535)
  Kemal.config.logging = false
end
