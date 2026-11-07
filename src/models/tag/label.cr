require "../tag"
require "../activity_pub/actor"
require "../activity_pub/object"

class Tag
  # A private label.
  #
  class Label < Tag
    belongs_to subject, class_name: ActivityPub::Object, foreign_key: subject_iri, primary_key: iri
    validates(subject) { "missing: #{subject_iri}" unless subject? }

    belongs_to owner, class_name: ActivityPub::Actor, foreign_key: href, primary_key: iri
    validates(owner) { "missing: #{href}" unless owner? }

    validates(name) do
      if name.blank?
        "is blank"
      elsif (instance = self.class.find?(href: href, subject_iri: subject_iri, name: name)) && instance.id != self.id
        "already exists: #{name}"
      end
    end

    def before_validate
      self.name = self.name.lstrip('§')
    end

    # label tags don't participate in tag statistics

    def after_create
      # no-op
    end

    def after_destroy
      # no-op
    end

    # The owner's labeled objects that are displayable.
    #
    private SOURCE = <<-SQL
        FROM objects AS o
        JOIN tags AS t
          ON t.subject_iri = o.iri
         AND t.type = 'Tag::Label'
        JOIN actors AS a
          ON a.iri = o.attributed_to_iri
       WHERE t.href = ?
         AND o.published IS NOT NULL
         #{common_filters(objects: "o", actors: "a")}
      SQL

    # Returns the label `t.id` for the given object id. Used to
    # translate the externally-supplied object id into the internal
    # cursor. Returns nil for unknown ids or ids of objects that
    # wouldn't appear in the result set.
    #
    private def self.translate_object_id_to_tag_id(owner : ActivityPub::Actor, name : String, o_id : Int64) : Int64?
      query = <<-QUERY
        SELECT MAX(t.id)
        #{SOURCE}
           AND t.name = ?
           AND o.id = ?
      QUERY
      ActivityPub::Object.scalar(query, owner.iri, name, o_id).as(Int64?)
    end

    # Returns the owner's objects with the given label.
    #
    # Orders objects by when they were labeled, most recent first.
    #
    def self.all_objects(owner : ActivityPub::Actor, name : String, *, max_id = nil, min_id = nil, limit = 10)
      max_id = translate_object_id_to_tag_id(owner, name, max_id) if max_id
      min_id = translate_object_id_to_tag_id(owner, name, min_id) if min_id
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
        #{SOURCE}
           AND t.name = ?
           AND %{cursor_condition}
      QUERY
      ActivityPub::Object.query_with_cursor(query, owner.iri, name, cursor_column: "t.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the count of the owner's objects with the given label.
    #
    # Counts the objects `all_objects` returns.
    #
    def self.all_objects_count(owner : ActivityPub::Actor, name : String)
      query = <<-QUERY
        SELECT count(*)
        #{SOURCE}
           AND t.name = ?
      QUERY
      ActivityPub::Object.scalar(query, owner.iri, name).as(Int64)
    end

    # Returns the names of the owner's labels, in order.
    #
    # Includes only labels on objects `all_objects` returns.
    #
    def self.names(owner : ActivityPub::Actor) : Array(String)
      query = <<-QUERY
        SELECT DISTINCT t.name
        #{SOURCE}
      QUERY
      Ktistec.database.query_all(query, owner.iri, as: String)
    end
  end
end
