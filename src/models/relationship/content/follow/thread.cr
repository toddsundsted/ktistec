require "../../../relationship"
require "../../../activity_pub/actor"
require "../../../activity_pub/object"

class Relationship
  class Content
    class Follow
      class Thread < Relationship
        belongs_to actor, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
        validates(actor) { "missing: #{from_iri}" unless actor? }

        # Identifies objects that are part of a thread.
        #
        # Has the form of an IRI but is not meant to be directly
        # dereferenceable.
        #
        derived thread : String, aliased_to: to_iri
        validates(thread) { "must not be blank" if thread.blank? }

        # Finds an existing relationship or instantiates a new
        # relationship.
        #
        # If `thread` (or `to_iri`) is passed as an option, search for
        # the root of the thread, and use that value. This ensures
        # that new relationships always point at roots.
        #
        def self.find_or_new(**options)
          if (thread = options[:thread]?) && (ephemeral = ActivityPub::Object.new(iri: thread).ancestors.last?)
            super(**options.merge({thread: ephemeral.thread}))
          elsif (to_iri = options[:to_iri]?) && (ephemeral = ActivityPub::Object.new(iri: to_iri).ancestors.last?)
            super(**options.merge({to_iri: ephemeral.thread}))
          else
            super(**options)
          end
        end

        # :ditto:
        def self.find_or_new(options)
          if (thread = options["thread"]?) && (ephemeral = ActivityPub::Object.new(iri: thread).ancestors.last?)
            super(options.merge({"thread" => ephemeral.thread}))
          elsif (to_iri = options["to_iri"]?) && (ephemeral = ActivityPub::Object.new(iri: to_iri).ancestors.last?)
            super(options.merge({"to_iri" => ephemeral.thread}))
          else
            super(options)
          end
        end

        # Merges relationships.
        #
        # Should be used in places where an object's thread property
        # is changed. Ensures that only one relationship exists for a
        # thread.
        #
        def self.merge_into(from, into)
          if from != into
            where(thread: from).each do |follow|
              if find?(actor: follow.actor, thread: into)
                follow.destroy
              else
                follow.assign(thread: into).save
              end
            end
          end
        end
      end
    end
  end
end

# updates the `thread` property when an object is saved. patching
# `Object` like this pulls the explicit dependency out of its source
# code.

module ActivityPub
  class Object
    def after_save
      previous_def
      Relationship::Content::Follow::Thread.merge_into(self.iri, self.thread)
    end
  end
end
