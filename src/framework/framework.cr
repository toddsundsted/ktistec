# TODO: remove when https://github.com/kemalcr/kemal/pull/566 is merged
require "flate"
require "gzip"
require "zlib"

require "kemal"
require "sqlite3"
require "uri"
require "yaml"

module Balloon
  class Config
    include YAML::Serializable

    property db_file : String

    def db_file
      "sqlite3://#{File.expand_path(@db_file, home: true)}"
    end
  end

  @@config : Config?

  def self.config
    @@config ||=
      File.open(File.expand_path(File.join("~", ".balloon.yml"), home: true)) do |file|
        Config.from_yaml(file)
      end
  end

  @@database : DB::Database?

  def self.database
    @@database ||= DB.open(Balloon.config.db_file)
  end

  @@secret_key : String?

  def self.secret_key
    @@secret_key ||= Balloon.database.scalar("SELECT value FROM options WHERE key = ?", "secret_key").as(String)
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
    Balloon.database.exec(query, "host", @@host)
    @@host
  end

  def self.host
    @@host ||= Balloon.database.scalar("SELECT value FROM options WHERE key = ?", "host").as(String)
  end

  def self.host?
    host
  rescue ex : Exception
    raise ex unless ex.message == "no results"
    false
  end

  # An [ActivityPub](https://www.w3.org/TR/activitypub/) server.
  #
  #     Balloon::Server.run do
  #       # configuration, initialization, etc.
  #     end
  #
  class Server
    def self.run
      unless File.exists?(Balloon.config.db_file.split("//").last)
        DB.open(Balloon.config.db_file) do |db|
          db.exec "CREATE TABLE options (key TEXT PRIMARY KEY, value TEXT)"
          db.exec "INSERT INTO options (key, value) VALUES (?, ?)", "secret_key", Random::Secure.hex(64)
          db.exec "CREATE TABLE migrations (id INTEGER PRIMARY KEY, name TEXT)"
        end
      end
      Balloon::Database.all_pending_versions.each do |version|
        puts Balloon::Database.do_operation(:apply, version)
      end
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
require "./method"
require "./auth"
