require "kemal"
require "sqlite3"
require "yaml"

module Balloon
  class Config
    YAML.mapping(
      db_file: String,
    )

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
          db.exec "CREATE TABLE migrations (id INTEGER PRIMARY KEY, name TEXT)"
          db.exec "CREATE TABLE options (key TEXT PRIMARY KEY, value TEXT)"
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

require "./database"
