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
  @@requests = [] of HTTP::Request
  @@activities = [] of ActivityPub::Activity
  @@collections = [] of ActivityPub::Collection
  @@actors = [] of ActivityPub::Actor
  @@objects = [] of ActivityPub::Object

  def self.last?
    @@requests.last?
  end

  def self.requests
    @@requests
  end

  def self.activities
    @@activities
  end

  def self.collections
    @@collections
  end

  def self.actors
    @@actors
  end

  def self.objects
    @@objects
  end

  def self.reset
    @@requests.clear
    @@activities.clear
    @@collections.clear
    @@actors.clear
    @@objects.clear
  end

  def self.get(url : String, headers : HTTP::Headers)
    @@requests << HTTP::Request.new("GET", url, headers)
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
    when /actors\/([^\/]+)\/([^\/]+)/
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers.new,
        body: (collection = @@collections.find { |c| c.iri == url.to_s }) ?
          collection.to_json_ld :
          <<-JSON
          {
            "@context":[
              "https://www.w3.org/ns/activitystreams"
            ],
            "type":"Collection",
            "id":"https://#{url.host}/#{$1}/#{$2}"
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
    when /objects\/([^\/]+)/
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers.new,
        body: (object = @@objects.find { |o| o.iri == url.to_s }) ?
          object.to_json_ld :
          <<-JSON
          {
            "@context":[
              "https://www.w3.org/ns/activitystreams"
            ],
            "type":"Object",
            "id":"https://#{url.host}/#{$1}"
          }
          JSON
      )
    else
      raise "request not mocked: GET #{url}"
    end
  end

  def self.post(url : String, headers : HTTP::Headers, body : String)
    @@requests << HTTP::Request.new("POST", url, headers, body)
    url = URI.parse(url)
    case url.path
    when /([^\/]+)\/inbox/
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers.new,
        body: ""
      )
    else
      raise "request not mocked: POST #{url}"
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
