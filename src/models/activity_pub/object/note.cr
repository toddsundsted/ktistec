require "../object"
require "./question"

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
      if !special && name && !content
        if (question = in_reply_to?).is_a?(ActivityPub::Object::Question)
          if (poll = question.poll?) && poll.options.any? { |option| option.name == name }
            self.special = "vote"
          end
        end
      end
    end
  end
end
