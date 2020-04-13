require "spectator"
require "kemal"
require "json"
require "xml"

# from https://github.com/kemalcr/spec-kemal/blob/master/src/spec-kemal.cr
# run specs with `KEMAL_ENV=test crystal spec`

class Global
  @@response : HTTP::Client::Response?

  def self.response=(@@response)
  end

  def self.response
    @@response
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
  client_response = HTTP::Client::Response.from_io(io, decompress: false)
  Global.response = client_response
end

def build_main_handler
  main_handler = Kemal.config.handlers.first
  current_handler = main_handler
  Kemal.config.handlers.each_with_index do |handler, index|
    current_handler.next = handler
    current_handler = handler
  end
  main_handler
end

def response
  Global.response.not_nil!
end

require "../src/framework"

module Balloon
  class SpecConfig
    def db_file
      @db_file ||= "sqlite3://#{File.tempname("balloon-test", ".db")}"
    end

    def host
      @host ||= "https://test.test"
    end
  end

  def self.config
    @@spec_config ||= SpecConfig.new
  end
end

class Actor
  private def cost
    4 # reduce the cost of computing a bcrypt hash
  end
end

Balloon::Server.run do
  Kemal.config.port = Random.new.rand(49152..65535)
  Kemal.config.logging = false
end
