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
    def clear_host
      Ktistec.database.exec("DELETE FROM options WHERE key = ?", "host")
      @host = nil
    end

    def clear_site
      Ktistec.database.exec("DELETE FROM options WHERE key = ?", "site")
      @site = nil
    end

    def clear_footer
      Ktistec.database.exec("DELETE FROM options WHERE key = ?", "footer")
      @footer = nil
    end
  end

  def self.clear_settings
    settings.clear_host
    settings.clear_site
    settings.clear_footer
    @@settings = nil
  end
end

macro setup_spec
  before_each do
    clazz = HTTP::Client
    if clazz.responds_to?(:reset)
      clazz.reset
    end
  end
  before_each { Ktistec.database.exec "SAVEPOINT __each__" }
  after_each { Ktistec.database.exec "ROLLBACK" }
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

Kemal.config.env = ENV["KEMAL_ENV"]? || "test"

Ktistec.settings.assign({"host" => "https://test.test", "site" => "Test"}).save

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
