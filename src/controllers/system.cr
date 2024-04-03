require "../framework/controller"

class SystemController
  include Ktistec::Controller

  get "/system" do |env|
    sources = Log.builder.sources

    log_levels = Ktistec::LogLevel.all_as_hash

    ok "system/index", env: env, log_levels: log_levels, sources: sources
  end

  post "/system" do |env|
    sources = Log.builder.sources

    log_levels = Ktistec::LogLevel.all_as_hash

    params = params(env)

    ::Log.setup do |c|
      backend = ::Log::IOBackend.new
      c.bind "*", Ktistec::LogLevel.default, backend
      sources.each do |source|
        unless (log_level = log_levels[source]?)
          log_level = Ktistec::LogLevel.new(source, :none)
        end
        if params && (param = params[source]?.presence)
          severity = log_level.severity = Log::Severity.parse(param)
          c.bind source, severity, backend
          log_level.save
        else
          log_level.destroy
        end
      end
    end

    redirect system_path
  end

  private def self.params(env)
    if accepts?("text/html")
      env.params.body
    elsif accepts?("application/json")
      env.params.json["logLevels"].as(Hash(String, JSON::Any)).transform_values(&.as_s?)
    end
  end
end
