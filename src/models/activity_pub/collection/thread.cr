require "../collection"
require "../object"

# Methods for working with a thread collection.
#
# This class does not itself represent a thread collection.
#
# ActivityPub objects that belong to the same thread all share the
# same `thread` property--the `iri` of the current root of the thread.
# Because the absolute root of the thread may not be known--it has not
# yet been fetched--the `thread` property of all objects associated
# with a thread, including the `iri` of the thread collection, may
# change as objects on the path to the root are fetched.
#
# The methods of this class help deal with that.
#
class ActivityPub::Collection::Thread
  # Finds an existing collection or instantiates a new collection.
  #
  def self.find_or_create(*, thread)
    ActivityPub::Collection.find_or_create(iri: thread)
  end

  # Merges collections.
  #
  # Should be used in places where an object's `thread` property
  # changes. Ensures that only one collection exists for a thread.
  #
  def self.merge_into(from, into)
    if from != into
      if (collection = ActivityPub::Collection.find?(from))
        unless ActivityPub::Collection.find?(into)
          collection.assign(iri: into).save
        else
          collection.destroy
        end
      end
    end
  end
end

# updates the `iri` property when an object is saved. patching
# `Object` like this pulls the explicit dependency out of its source
# code.

module ActivityPub
  class Object
    def after_save
      previous_def
      ActivityPub::Collection::Thread.merge_into(self.iri, self.thread)
    end
  end
end
