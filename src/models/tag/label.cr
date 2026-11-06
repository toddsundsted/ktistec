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
  end
end
