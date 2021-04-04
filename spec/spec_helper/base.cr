require "spectator"
require "http/request"

require "../../src/framework"

class String
  def ===(other : HTTP::Request)
    "#{other.method} #{other.resource}" == self
  end
end

class Regex
  def ===(other : HTTP::Request)
    "#{other.method} #{other.resource}" =~ self
  end
end

class Array(T)
  def ==(other : Ktistec::Util::PaginatedArray(U)) forall U
    other.to_a == self
  end
end

module Ktistec
  def self.db_file
    @@db_file ||= "sqlite3://#{File.tempname("ktistec-test", ".db")}"
  end

  def self.clear_host
    Ktistec.database.exec("DELETE FROM options WHERE key = ?", "host")
    @@host = nil
  end

  def self.clear_site
    Ktistec.database.exec("DELETE FROM options WHERE key = ?", "site")
    @@site = nil
  end

  def self.clear_footer
    Ktistec.database.exec("DELETE FROM options WHERE key = ?", "footer")
    @@footer = nil
  end
end

class Account
  private def cost
    4 # reduce the cost of computing a bcrypt hash
  end
end

macro setup_spec
  before_each do
    clazz = HTTP::Client
    if clazz.responds_to?(:reset)
      clazz.reset
    end
  end
  before_each { Ktistec.database.exec "SAVEPOINT __test__" }
  after_each { Ktistec.database.exec "ROLLBACK" }
end

def self.random_string
  ('a'..'z').to_a.shuffle.first(8).join
end

def self.random_username
  random_string
end

def self.random_password
  random_string + "1="
end

Ktistec.host = "https://test.test"
Ktistec.site = "Test"

Log.setup_from_env
