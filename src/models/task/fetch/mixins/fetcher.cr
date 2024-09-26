require "../../../task"

class Task
  module Fetch::Fetcher
    # Temporary cache of undereferenceable IRIs. The same IRIs are
    # often found in more than one collection. This cache avoids
    # spending resources fetching when an IRI has failed once and may
    # fail again in the near future. The cache is not persisted across
    # invocations of `perform`.
    #
    @bad_iris = Set(String).new

    # Finds or fetches an object.
    #
    # Returns a tuple that indicates whether the object was fetched
    # or not, along with the object or `nil` if the object can't be
    # dereferenced.
    #
    # Saves/caches fetched objects.
    #
    private def find_or_fetch_object(iri, *, include_deleted = false, include_blocked = false)
      fetched = false
      if (object = check_object(iri))
        if (object.deleted? && !include_deleted) || (object.blocked? && !include_blocked)
          object = nil
        elsif object.new_record?
          if (attributed_to_iri = object.attributed_to_iri) && (attributed_to = check_actor(attributed_to_iri))
            if (!attributed_to.deleted? || include_deleted) && (!attributed_to.blocked? || include_blocked)
              fetched = true
              object.attributed_to = attributed_to
              object.save
            else
              object = nil
            end
          else
            object = nil
          end
        end
      end
      {fetched, object}
    end

    private def check_object(iri)
      unless iri.in?(@bad_iris)
        unless (object = ActivityPub::Object.dereference?(source, iri, include_deleted: true))
          @bad_iris << iri
        end
      end
      object
    end

    private def check_actor(iri)
      unless iri.in?(@bad_iris)
        unless (actor = ActivityPub::Actor.dereference?(source, iri, include_deleted: true))
          @bad_iris << iri
        end
      end
      actor
    end

    enum ::Task::Fetch::Horizon
      ImmediateFuture
      NearFuture
      FarFuture
    end

    # Count of successive failures to fetch new objects.
    #
    delegate :failures, :last_success_at, to: state

    # Returns the time at which the next fetch should be attempted.
    #
    private def calculate_next_attempt_at(horizon : Horizon)
      random = Random::DEFAULT
      case horizon
      in Horizon::ImmediateFuture
        state.failures = 0
        random.rand(6..10).seconds.from_now
      in Horizon::NearFuture
        state.failures = 0
        random.rand(90..150).minutes.from_now
      in Horizon::FarFuture
        state.failures += 1
        base = Math.min(2 ** (state.failures + 1), 168) # max 1 week
        offset = base // 4
        min = base - offset
        max = base + offset
        random.rand(min..max).hours.from_now
      end
    end

    # Sets `next_attempt_at`.
    #
    private def set_next_attempt_at(maximum, count, continuation = false)
      unless interrupted?
        if count < 1 && !continuation
          if follow?
            self.next_attempt_at =
              calculate_next_attempt_at(Horizon::FarFuture)
          end
        elsif count < maximum
          if follow?
            self.next_attempt_at =
              calculate_next_attempt_at(Horizon::NearFuture)
          end
        else
          self.next_attempt_at =
            calculate_next_attempt_at(Horizon::ImmediateFuture)
        end
      end
    end

    # Sets the task to complete.
    #
    def complete!
      update_property(:complete, true)
    end

    private property interrupted : Bool = false

    # Indicates whether the task was asynchronously set as complete.
    #
    def interrupted?
      @interrupted ||= self.class.find(self.id).complete
    end
  end
end
