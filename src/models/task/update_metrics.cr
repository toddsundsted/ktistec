require "../account"
require "../point"
require "../task"
require "./mixins/singleton"

class Task
  # Updates metrics.
  #
  class UpdateMetrics < Task
    include Singleton

    Log = ::Log.for(self)

    class State
      include JSON::Serializable

      property last_id : Int64?

      def initialize(@last_id = nil)
      end
    end

    @[Persistent]
    @[Insignificant]
    property state : State { State.new }

    def last_id
      state.last_id
    end

    def last_id=(last_id)
      state.last_id = last_id
    end

    alias Key = Tuple(String, Time)

    private def accumulate(relationship_types)
      types = relationship_types.map(&.to_s).join("','")
      items =
        if (last_id = self.last_id)
          Relationship.where("id > ? AND type IN ('#{types}') ORDER BY id", last_id)
        else
          Relationship.where("type IN ('#{types}') ORDER BY id")
        end

      account_timezone_cache = Hash(String, {Account, Time::Location}?).new do |hash, iri|
        if (account = Account.find?(iri: iri))
          timezone = Time::Location.load(account.timezone)
          hash[iri] = {account, timezone}
        else
          Log.info { "Skipping relationship for terminated account: #{iri}" }
          hash[iri] = nil
        end
      end

      counts = items.reduce(Hash(Key, Int32).new(0)) do |acc, relationship|
        if (account_timezone = account_timezone_cache[relationship.from_iri])
          account, timezone = account_timezone
          key = Key.new(
            "#{relationship.type.split("::").last.downcase}-#{account.username}",
            relationship.created_at.in(timezone).at_beginning_of_hour
          )
          acc[key] += 1
        end
        acc
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
      self.next_attempt_at = randomized_next_attempt_at(1.hour)
    end
  end
end
