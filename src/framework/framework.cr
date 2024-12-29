require "kemal"
require "sqlite3"
require "uri"

require "./ext/array"
require "./ext/hash"
require "./ext/log"
require "./database"
require "../utils/translator"

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
    PROPERTIES = {
      host: String,
      site: String,
      footer: String,
      translator_service: String,
      translator_url: String,
    }

    {% for property, type in PROPERTIES %}
      property {{property.id}} : {{type.id}}?
    {% end %}

    getter errors = Hash(String, Array(String)).new

    def initialize
      values =
        Ktistec.database.query_all("SELECT key, value FROM options", as: {String, String?})
          .reduce(Hash(String, String?).new) do |values, (key, value)|
            values[key] = value
            values
          end
      assign(values)
    end

    def assign(options)
      {% for property, type in PROPERTIES %}
        @{{property.id}} = options["{{property.id}}"].as({{type.id}}?) if options.has_key?("{{property.id}}")
      {% end %}
      self
    end

    private SQL = "INSERT OR REPLACE INTO options (key, value) VALUES (?, ?)"

    def save
      raise "invalid settings" unless valid?
      {% for property, _ in PROPERTIES %}
        Ktistec.database.exec(SQL, "{{property.id}}", @{{property.id}})
      {% end %}
      self
    end

    def valid?
      errors.clear
      host_errors = [] of String
      if (host = @host.presence)
        uri = URI.parse(host)
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
        host_errors << "must be present"
      end
      errors["host"] = host_errors unless host_errors.empty?
      errors["site"] = ["name must be present"] unless @site.presence
      if (translator_service = @translator_service.presence)
        unless translator_service.in?("deepl", "libretranslate")
          errors["translator_service"] = ["is not supported"]
        end
      end
      url_errors = [] of String
      if (url = @translator_url.presence)
        uri = URI.parse(url)
        url_errors << "must have a scheme" unless uri.scheme.presence
        url_errors << "must have a host name" unless uri.host.presence
        url_errors << "must not have a fragment" if uri.fragment.presence
      end
      errors["translator_url"] = url_errors unless url_errors.empty?
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

  @@translator : Ktistec::Translator? = nil

  def self.translator
    @@translator ||=
      begin
        if (service = settings.translator_service) && (url = settings.translator_url)
          case service
          when "deepl"
            if (key = ENV["DEEPL_API_KEY"]?)
              Ktistec::Translator::DeepLTranslator.new(URI.parse(url), key)
            end
          when "libretranslate"
            if (key = ENV["LIBRETRANSLATE_API_KEY"]?)
              Ktistec::Translator::LibreTranslateTranslator.new(URI.parse(url), key)
            end
          end
        end
      end
  end

  {% for property, _ in Settings::PROPERTIES %}
    def self.{{property.id}}
      settings.{{property.id}}.not_nil!
    end
  {% end %}

  # An [ActivityPub](https://www.w3.org/TR/activitypub/) server.
  #
  #     Ktistec::Server.run do
  #       # configuration, initialization, etc.
  #     end
  #
  class Server
    def self.run
      log_levels = LogLevel.all_as_hash
      ::Log.setup log_levels.transform_values(&.severity)
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
