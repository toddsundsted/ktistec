require "../framework/controller"

class SystemController
  include Ktistec::Controller

  get "/system" do |env|
    sources = Log.builder.sources

    log_levels = Ktistec::LogLevel.all_as_hash

    ok "system/index", env: env, log_levels: log_levels, sources: sources
  end

  post "/system" do |env|
    params = params(env)

    sources = Log.builder.sources

    log_levels = Ktistec::LogLevel.all_as_hash

    sources.each do |source|
      if params && (param = params[source]?.presence)
        log_levels[source] = Ktistec::LogLevel.new(source, Log::Severity.parse(param)).save
      else
        log_levels.delete(source).try(&.destroy)
      end
    end

    ::Log.setup log_levels.transform_values(&.severity)

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
