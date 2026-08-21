require "../object"
require "./question"

class ActivityPub::Object
  class Note < ActivityPub::Object
    @@external = false

    def before_save
      super
      detect_vote
    end

    # Detect whether this `Note` is a vote, and maintain that
    # decision.
    #
    # A vote is decided once. Until it is, the note is classified by
    # its structure. Once decided, the decision does not change.
    #
    private def detect_vote
      if self.special.in?({"vote", "ignored_vote"})
        if !new_record? && (saved = @saved_record)
          self.name = saved.name if changed?(:name)
        end
      elsif !self.special && self.name && !self.content
        if (question = self.in_reply_to?).is_a?(ActivityPub::Object::Question)
          if (poll = question.poll?) && poll.options.any? { |option| option.name == self.name }
            self.special =
              question.local? && !question.accepts_vote?(self) ? "ignored_vote" : "vote"
          end
        end
      end
    end
  end
end
