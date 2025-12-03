require "../tag"
require "../activity_pub/actor"
require "../activity_pub/object"

class Tag
  class Emoji < Tag
    belongs_to subject, class_name: ActivityPub::Actor | ActivityPub::Object, foreign_key: subject_iri, primary_key: iri
    validates(subject) { "missing: #{subject_iri}" unless subject? }

    validates(name) { "is blank" if name.blank? }
    validates(href) { "is blank" unless href.presence }

    def before_save
      # mastodon shortcodes are case-sensitive (:blob: ≠ :Blob:)
      self.name = self.name.strip.delete(':')
    end

    # emoji tags don't participate in tag statistics

    def after_create
      # no-op
    end

    def after_destroy
      # no-op
    end
  end
end
