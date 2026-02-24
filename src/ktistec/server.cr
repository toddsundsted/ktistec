{% if compare_versions(Crystal::VERSION, "1.19.1") < 0 %}
  {% raise "Crystal version >= 1.19.1 is required: #{Crystal::VERSION} is not supported" %}
{% end %}

require "../rules/**"
require "../framework/**"
require "../models/**"
require "../controllers/**"
require "../handlers/**"
require "../workers/**"

Ktistec::Server.run do
  Kemal.config.extra_options do |opts|
    opts.on("--full-garbage-collection-on-startup", "Runs full garbage collection on startup") do
      puts "WARNING: Garbage collection can take a long time and cannot be safely interrupted."
      puts "WARNING: Please ensure you have a backup of your database. You have 10 seconds to abort."
      (1..10).each do |i|
        print "#{i}..."
        STDOUT.flush
        sleep 1.second
      end
      puts ""
      Task::CollectGarbage.new.perform_on_demand
    end
  end
  TaskWorker.start do
    Task.destroy_old_tasks
    Task.clean_up_running_tasks
    Task::Backup.ensure_scheduled
    Task::Performance.ensure_scheduled
    Task::UpdateMetrics.ensure_scheduled
    Task::Monitor.ensure_scheduled
    Task::RunScripts.ensure_scheduled
    Task::CleanOauth.ensure_scheduled
  end
  Session.clean_up_stale_sessions
  # track server starts
  Point.new(chart: "server-start", timestamp: Time.utc, value: 1).save
  # check the rules when the server starts
  ContentRules.domain
end
