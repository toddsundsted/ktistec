require "../object"

class ActivityPub::Object
  # A question.
  #
  # Note: a question is an object, as per Mastodon's implementation:
  #   https://docs.joinmastodon.org/spec/activitypub/#Question
  # It is not an activity, as per the Activity Streams specification:
  #   https://www.w3.org/TR/activitystreams-vocabulary/#dfn-question
  #
  class Question < ActivityPub::Object
  end
end
