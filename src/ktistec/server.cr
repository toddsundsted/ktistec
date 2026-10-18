{% if compare_versions(Crystal::VERSION, "1.19.1") < 0 %}
  {% raise "Crystal version >= 1.19.1 is required: #{Crystal::VERSION} is not supported" %}
{% elsif compare_versions(Crystal::VERSION, "1.20.0") == 0 %}
  {% raise "Crystal 1.20.0 is not supported (lexer regression in percent-literal macro interpolation): use 1.19.x or >= 1.20.1" %}
{% end %}

require "../rules/**"       # ameba:disable Ktistec/NoRequireGlob
require "../framework/**"   # ameba:disable Ktistec/NoRequireGlob
require "../models/**"      # ameba:disable Ktistec/NoRequireGlob
require "../controllers/**" # ameba:disable Ktistec/NoRequireGlob
require "../handlers/**"    # ameba:disable Ktistec/NoRequireGlob
require "../workers/**"     # ameba:disable Ktistec/NoRequireGlob
require "../services/feed/judging"
require "../services/feed/queue"
require "../services/feed/backend/criteria"
require "../services/feed/judges"

Ktistec::Server.run do
  Feed::Judges.scan
  Rules::Feeds.register_all
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
    Feed::Queue.release_batches
    Task::Backup.ensure_scheduled
    Task::Performance.ensure_scheduled
    Task::UpdateMetrics.ensure_scheduled
    Task::Monitor.ensure_scheduled
    Task::RunScripts.ensure_scheduled
    Task::CleanOauth.ensure_scheduled
    Task::ReconcileTagStatistics.ensure_scheduled
    Task::Feed::CollectDrafts.ensure_scheduled
    Task::Feed::CollectOrphans.ensure_scheduled
    Task::Feed::AnswerQuestions.ensure_scheduled
    Task::Feed::DiscoverJudges.ensure_scheduled
  end
  Session.clean_up_stale_sessions
  # track server starts
  Point.new(chart: "server-start", timestamp: Time.utc, value: 1).save
end
