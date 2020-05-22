# TODO: remove when https://github.com/kemalcr/kemal/pull/566 is merged
require "flate"
require "gzip"
require "zlib"

require "kemal"
require "sqlite3"
require "yaml"

module Balloon
  class Config
    YAML.mapping(
      db_file: String,
      host: String,
    )

    def db_file
      "sqlite3://#{File.expand_path(@db_file, home: true)}"
    end

    def host
      @host
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

require "./util"
require "./controller"
require "./database"
require "./model"
require "./json_ld"
require "./jwt"
require "./auth"
