require "kemal"
require "kilt/slang"
require "sqlite3"
require "uri"
require "yaml"

module Ktistec
  class Config
    def db_file
      @db_file ||=
        if Kemal.config.env == "production"
          "sqlite3://#{File.expand_path("~/.ktistec.db", home: true)}"
        else
          "sqlite3://ktistec.db"
        end
    end
  end

  def self.config
    @@config ||= Config.new
  end

  @@database : DB::Database?

  def self.database
    @@database ||= DB.open(Ktistec.config.db_file)
  end

  @@secret_key : String?

  def self.secret_key
    @@secret_key ||= Ktistec.database.scalar("SELECT value FROM options WHERE key = ?", "secret_key").as(String)
  end

  @@host : String?

  private def self.present?(value)
    !value.nil? && !value.empty? && value
  end

  def self.host=(host)
    uri = URI.parse(host)
    raise "scheme must be present" unless present?(uri.scheme)
    raise "host must be present" unless present?(uri.host)
    raise "fragment must not be present" if present?(uri.fragment)
    raise "query must not be present" if present?(uri.query)
    if (path = present?(uri.path))
      raise "path must not be present" unless path == "/"
      uri.path = ""
    end
    @@host = uri.normalize.to_s
    query = "INSERT OR REPLACE INTO options (key, value) VALUES (?, ?)"
    Ktistec.database.exec(query, "host", @@host)
    @@host
  end

  def self.host
    @@host ||= Ktistec.database.scalar("SELECT value FROM options WHERE key = ?", "host").as(String)
  end

  def self.host?
    host
  rescue ex : Exception
    raise ex unless ex.message == "no results"
    false
  end

  # An [ActivityPub](https://www.w3.org/TR/activitypub/) server.
  #
  #     Ktistec::Server.run do
  #       # configuration, initialization, etc.
  #     end
  #
  class Server
    def self.run
      unless File.exists?(Ktistec.config.db_file.split("//").last)
        DB.open(Ktistec.config.db_file) do |db|
          db.exec "CREATE TABLE options (key TEXT PRIMARY KEY, value TEXT)"
          db.exec "INSERT INTO options (key, value) VALUES (?, ?)", "secret_key", Random::Secure.hex(64)
          db.exec "CREATE TABLE migrations (id INTEGER PRIMARY KEY, name TEXT)"
        end
      end
      Ktistec::Database.all_pending_versions.each do |version|
        puts Ktistec::Database.do_operation(:apply, version)
      end
      # clean out stale, anonymous sessions
      Ktistec.database.exec "DELETE FROM sessions WHERE account_id IS NULL AND updated_at < date('now', '-1 days')"
      with new yield
      Kemal.run
    end
  end

  # :nodoc:
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end

require "./ext/*"
require "./util"
require "./controller"
require "./database"
require "./model"
require "./json_ld"
require "./jwt"
require "./signature"
require "./csrf"
require "./auth"
require "./method"
