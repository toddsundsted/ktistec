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
    # Returns a tuple that indicaates whether the object was fetched
    # or not, along with the object or `nil` if the object can't be
    # dereferenced.
    #
    # Saves/caches fetched objects.
    #
    private def find_or_fetch_object(iri)
      fetched = false
      if (object = check_object(iri))
        if object.new_record?
          if (attributed_to_iri = object.attributed_to_iri) && (attributed_to = check_actor(attributed_to_iri))
            if !attributed_to.blocked?
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
  end
end
