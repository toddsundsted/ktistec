require "../task"
require "./mixins/singleton"
require "../feed"

class Task
  # Collection task for abandoned feed drafts.
  #
  # Drafts are destroyed one at a time, through the model, so
  # `Feed#before_destroy` deletes each draft's verdicts and
  # materialized rows.
  #
  class CollectFeedDrafts < Task
    include Singleton

    Log = ::Log.for(self)

    # generous because the lease is renewed by saving, not by viewing:
    # revisiting a draft without previewing it does not save it.
    DEFAULT_MAX_AGE_HOURS = 24 * 7

    def perform(max_age_hours = DEFAULT_MAX_AGE_HOURS)
      Log.debug { "Starting cleanup of feed drafts abandoned for more than #{max_age_hours} hours" }

      deleted_count = collect_abandoned_drafts(max_age_hours)

      Log.debug { "Feed draft cleanup completed: deleted #{deleted_count} drafts" }

      deleted_count
    ensure
      self.next_attempt_at = randomized_next_attempt_at(1.day)
    end

    private def collect_abandoned_drafts(max_age_hours : Int32)
      drafts = Feed.where("draft = 1 AND updated_at < ?", max_age_hours.hours.ago)
      drafts.each(&.destroy)
      drafts.size
    end
  end
end
