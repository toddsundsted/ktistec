require "../object"

class ActivityPub::Object
  class Note < ActivityPub::Object
    @@external = false

    def before_save
      super
      detect_vote
    end

    # Detect if this `Note` is a vote based on its structure.
    #
    private def detect_vote
      if !self.special && self.name && !self.content
        if (question = self.in_reply_to?).is_a?(ActivityPub::Object::Question)
          if (poll = question.poll?) && poll.options.any? { |option| option.name == self.name }
            self.special = "vote"
          end
        end
      end
    end
  end
end
