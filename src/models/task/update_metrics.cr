require "../account"
require "../point"
require "../task"

class Task
  # Updates metrics.
  #
  class UpdateMetrics < Task
    private class State
      include JSON::Serializable

      property last_id : Int64?

      def initialize(@last_id = nil)
      end
    end

    private def state_or_new
      if (state = self.state)
        State.from_json(state)
      else
        State.new
      end
    end

    def last_id
      state_or_new.last_id
    end

    def last_id=(last_id)
      state_or_new.tap do |state|
        state.last_id = last_id
        self.state = state.to_json
      end.last_id
    end

    def initialize(*args, **opts)
      self.source_iri = ""
      self.subject_iri = ""
      super(*args, **opts)
    end

    def self.schedule_unless_exists
      if self.where("running = 0 AND complete = 0 AND backtrace IS NULL").empty?
        self.new.schedule
      end
    end

    alias Key = Tuple(String, Time)

    private def accumulate(relationship_types)
      types = relationship_types.map(&.to_s.dump).join(",")
      items =
        if (last_id = self.last_id)
          Relationship.where("id > ? AND type IN (#{types}) ORDER BY id", last_id)
        else
          Relationship.where("type IN (#{types}) ORDER BY id")
        end

      counts = items.reduce(Hash(Key, Int32).new(0)) do |counts, relationship|
        account = Account.find(iri: relationship.from_iri)
        timezone = Time::Location.load(account.timezone)
        key = Key.new(
          "#{relationship.type.split("::").last.downcase}-#{account.username}",
          relationship.created_at.in(timezone).at_beginning_of_day
        )
        counts[key] += 1
        counts
      end

      counts.each do |(key, value)|
        chart, timestamp = key
        unless (point = Point.find?(chart: chart, timestamp: timestamp))
          point = Point.new(chart: chart, timestamp: timestamp, value: 0)
        end
        point.value += value
        point.save
      end

      unless items.empty?
        self.last_id = items.last.id
      end
    end

    def perform
      accumulate([Relationship::Content::Inbox, Relationship::Content::Outbox])
    ensure
      self.next_attempt_at = 1.hour.from_now
    end
  end
end
