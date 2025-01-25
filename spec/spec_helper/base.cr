require "spectator"
require "http/request"
require "xml/node"
require "json"

require "../../src/framework"

# require specific classes for later redefinitions

require "../../src/models/account"
require "../../src/models/task"

## Helpers for spec matchers

class String
  def ===(other : HTTP::Request)
    "#{other.method} #{other.resource}" == self
  end

  def ==(other : XML::Node)
    other.content == self
  end

  def ==(other : JSON::Any)
    other.raw == self
  end
end

class Regex
  def ===(other : HTTP::Request)
    "#{other.method} #{other.resource}" =~ self
  end

  def ==(other : XML::Node)
    !!(other.content =~ self)
  end

  def ==(other : JSON::Any)
    !!(other.raw =~ self)
  end
end

class HTTP::Request
  def ===(other : String)
    other == "#{self.method} #{self.resource}"
  end

  def ===(other : Regex)
    other =~ "#{self.method} #{self.resource}"
  end
end

class XML::Node
  def ==(other : String)
    other == self.content
  end

  def ==(other : Regex)
    !!(other =~ self.content)
  end
end

struct JSON::Any
  def empty?
    as_a.empty?
  end
end

class Array(T)
  def ==(other : Ktistec::Util::PaginatedArray(U)) forall U
    other.to_a == self
  end
end

## Redefinitions

class Account
  private def cost
    4 # reduce the cost of computing a bcrypt hash
  end

  private def size
    512 # reduce the size of the generated rsa key
  end
end

class Task
  def schedule(next_attempt_at = nil)
    previous_def(next_attempt_at).tap { perform } # always perform when testing
  end
end

## Test setup/teardown

module Ktistec
  @@db_file = "sqlite3://#{File.tempname("ktistec-test", ".db")}"

  class Settings
    {% for property in PROPERTIES %}
      def clear_{{property.id}}
        Ktistec.database.exec("DELETE FROM options WHERE key = ?", "{{property.id}}")
        @{{property.id}} = nil
      end
    {% end %}
  end

  def self.clear_settings
    {% for property in Settings::PROPERTIES %}
      settings.clear_{{property.id}}
    {% end %}
    @@settings = nil
  end

  def self.set_default_settings
    Ktistec.settings.assign({
      "host" => "https://test.test/",
      "site" => "Test",
      "footer" => nil,
    }).save
  end

  @@mocks = [] of Ktistec::Translator

  def self.check_translator
    return if @@translator && @@mocks.includes?(@@translator)
    previous_def
  end

  def self.set_translator(translator : Ktistec::Translator)
    @@translator = translator
    @@mocks << translator
  end

  def self.clear_translator
    settings.clear_translator_service
    settings.clear_translator_url
    @@translator = nil
    @@mocks.clear
  end
end

BEFORE_PROCS = [] of Proc(Nil)
AFTER_PROCS = [] of Proc(Nil)

BEFORE_PROCS << -> do
  Ktistec.database.exec "SAVEPOINT __each__"
end
AFTER_PROCS << -> do
  Ktistec.database.exec "ROLLBACK"
end

{% if @top_level.has_constant?("Tag") %}
  BEFORE_PROCS << -> do
    Tag.cache.clear
  end
{% end %}

macro setup_spec
  before_each { BEFORE_PROCS.each(&.call) }
  after_each { AFTER_PROCS.each(&.call) }
end

## Helpers for test instance creation

def self.random_string
  ('a'..'z').to_a.shuffle.first(8).join
end

def self.random_username
  random_string
end

def self.random_password
  random_string + "1="
end

## Test configuration

Kemal.config.public_folder = Dir.tempdir

Kemal.config.env = ENV["KEMAL_ENV"]? || "test"

Ktistec.set_default_settings

# Spectator calls `setup_from_env` to set up logging. the dispatcher
# default (`DispatchMode::Async`) does not work -- probably due to:
# https://github.com/icy-arctic-fox/spectator/issues/27

# and, even if this is fixed, we prefer synchronous output when
# running specs.

class Log
  def self.setup_from_env(*, dispatcher : DispatchMode = DispatchMode::Sync, default_level : Severity = Severity::None)
    previous_def(backend: IOBackend.new(dispatcher: dispatcher), default_level: default_level)
  end
end
