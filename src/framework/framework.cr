require "kemal"
require "kilt/slang"
require "sqlite3"
require "uri"
require "yaml"

module Ktistec
  def self.db_file
    @@db_file ||=
      if Kemal.config.env == "production"
        "sqlite3://#{File.expand_path("~/.ktistec.db", home: true)}"
      else
        "sqlite3://ktistec.db"
      end
  end

  @@database : DB::Database?

  def self.database
    @@database ||= begin
      unless File.exists?(Ktistec.db_file.split("//").last)
        DB.open(Ktistec.db_file) do |db|
          db.exec "CREATE TABLE options (key TEXT PRIMARY KEY, value TEXT)"
          db.exec "INSERT INTO options (key, value) VALUES (?, ?)", "secret_key", Random::Secure.hex(64)
          db.exec "CREATE TABLE migrations (id INTEGER PRIMARY KEY, name TEXT)"
        end
      end
      DB.open(Ktistec.db_file)
    end
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

  def self.site=(site)
    raise "must be present" unless present?(site)
    @@site = site
    query = "INSERT OR REPLACE INTO options (key, value) VALUES (?, ?)"
    Ktistec.database.exec(query, "site", @@site)
    @@site
  end

  def self.site
    @@site ||= Ktistec.database.scalar("SELECT value FROM options WHERE key = ?", "site").as(String)
  end

  def self.site?
    site
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
      Ktistec::Database.all_pending_versions.each do |version|
        puts Ktistec::Database.do_operation(:apply, version)
      end
      with new yield
      Kemal.run
    end
  end

  # :nodoc:
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end
