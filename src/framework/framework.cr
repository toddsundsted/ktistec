require "kemal"
require "sqlite3"
require "uri"

require "./ext/array"
require "./ext/hash"
require "./ext/log"
require "./database"

module Ktistec
  # always run database migrations when we boot up the framework
  Ktistec::Database.all_pending_versions.each do |version|
    puts Ktistec::Database.do_operation(:apply, version)
  end

  # Model-like class for managing log levels.
  #
  class LogLevel
    property source : String
    property severity : Log::Severity

    def initialize(source, severity)
      @source = source
      @severity = severity
    end

    def save
      Ktistec.database.exec(
        "INSERT OR REPLACE INTO options (key, value) VALUES (?, ?)",
        "log_level/#{@source}", @severity.to_s
      )
      self
    end

    def destroy
      Ktistec.database.exec(
        "DELETE FROM options WHERE key = ?",
        "log_level/#{@source}"
      )
      self
    end

    def self.all_as_hash
      Ktistec.database.query_all("SELECT key, value FROM options WHERE key LIKE 'log_level/%'", as: {String, String})
        .reduce(Hash(String, LogLevel).new) do |log_levels, (key, value)|
          key = key.lchop("log_level/")
          log_levels[key] =  LogLevel.new(key, Log::Severity.parse(value))
          log_levels
        end
    end

    def ==(other)
      other.is_a?(LogLevel) && @source == other.source && @severity == other.severity
    end
  end

  # Model-like class for managing site settings.
  #
  class Settings
    property host : String?
    property site : String?
    property footer : String?

    getter errors = Hash(String, Array(String)).new

    def initialize
      values =
        Ktistec.database.query_all("SELECT key, value FROM options", as: {String, String?}).reduce(Hash(String, String?).new) do |values, (key, value)|
          values[key] = value
          values
        end
      assign(values)
    end

    def save
      raise "invalid settings" unless valid?
      {"host" => @host, "site" => @site, "footer" => @footer}.each do |key, value|
        Ktistec.database.exec("INSERT OR REPLACE INTO options (key, value) VALUES (?, ?)", key, value)
      end
      self
    end

    def assign(options)
      @host = options["host"].as(String) if options.has_key?("host")
      @site = options["site"].as(String) if options.has_key?("site")
      @footer = options["footer"].as(String?) if options.has_key?("footer")
      self
    end

    def valid?
      errors.clear
      host_errors = [] of String
      if (host = @host) && !host.empty?
        uri = URI.parse(host)
        # `URI.parse` treats something like "ktistec.com" as a path
        # name and not a host name. users expectations differ.
        if !uri.host.presence && uri.path.presence
          parts = uri.path.split('/', 2)
          unless parts.first.blank?
            uri.host = parts.first
            uri.path = parts.fetch(1, "")
          end
        end
        host_errors << "must have a scheme" unless uri.scheme.presence
        host_errors << "must have a host name" unless uri.host.presence
        host_errors << "must not have a fragment" if uri.fragment.presence
        host_errors << "must not have a query" if uri.query.presence
        host_errors << "must not have a path" if uri.path.presence && uri.path != "/"
        if host_errors.empty? && uri.path == "/"
          uri.path = ""
          @host = uri.normalize.to_s
        end
      else
        host_errors << "name must be present"
      end
      errors["host"] = host_errors unless host_errors.empty?
      errors["site"] = ["name must be present"] unless @site.presence
      errors.empty?
    end
  end

  def self.settings
    # return a new instance if the old instance had validation errors
    @@settings =
      begin
        settings = @@settings
        settings.nil? || !settings.errors.empty? ? Settings.new : settings
      end
  end

  def self.host
    settings.host.not_nil!
  end

  def self.site
    settings.site.not_nil!
  end

  def self.footer
    settings.footer.not_nil!
  end

  # An [ActivityPub](https://www.w3.org/TR/activitypub/) server.
  #
  #     Ktistec::Server.run do
  #       # configuration, initialization, etc.
  #     end
  #
  class Server
    def self.run
      with new yield
      Kemal.config.app_name = "Ktistec"
      # work around Kemal's handling of the command line when running specs...
      argv = (Kemal.config.env == "test") ? typeof(ARGV).new : ARGV
      Kemal.run argv
    end
  end

  # :nodoc:
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end
