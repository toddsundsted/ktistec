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
      env.session = session
      env.account = account
    end
    return call_next(env)
  end
end

class DummyCSRF < Kemal::Handler
  def call(env)
    env.session.string("csrf", "CSRF TOKEN")
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
    if handler.is_a?(Ktistec::Auth) && Global.session && Global.account
      # if we "sign_in" in a context, swap in the dummy handler
      handler = DummyAuth.new
    elsif handler.is_a?(Ktistec::CSRF)
      handler = DummyCSRF.new
    end
    current_handler.next = handler
    current_handler = handler
  end
  main_handler
end

def response
  Global.response.not_nil!
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

require "../src/framework"
require "../src/framework/ext/**"
require "../src/framework/open"
require "../src/framework/util"
require "../src/framework/controller"
require "../src/framework/database"
require "../src/framework/model"
require "../src/framework/json_ld"
require "../src/framework/jwt"
require "../src/framework/signature"
require "../src/framework/csrf"
require "../src/framework/auth"
require "../src/framework/rewrite"
require "../src/framework/method"
require "../src/workers/**"

require "./spec_helper/base"
require "./spec_helper/network"
require "./spec_helper/register"

Ktistec::Server.run do
  Log.setup_from_env
  Kemal.config.port = Random.new.rand(49152..65535)
  Kemal.config.logging = false
end
