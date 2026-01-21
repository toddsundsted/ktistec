require "../framework/model"
require "./activity_pub/object/question"
require "./task/notify_poll_expiry"

class Poll
  include Ktistec::Model
  include Ktistec::Model::Common

  @@table_name = "polls"

  @[Persistent]
  property question_iri : String?
  belongs_to question, class_name: ActivityPub::Object::Question, foreign_key: question_iri, primary_key: iri, inverse_of: poll
  validates(question) { "must be present" unless question? }

  class Option
    include JSON::Serializable

    property name : String
    property votes_count : Int32

    def initialize(@name : String, @votes_count : Int32 = 0)
    end
  end

  @[Persistent]
  property options : Array(Option) { [] of Option }
  validates(options) do
    return "must contain at least 2 options" unless options.size > 1
    return "must be unique" unless options.map(&.name).uniq!.size == options.size
    if !new_record? && changed?(:options)
      if (q = question?) && q.local? && !q.draft?
        if (s = @saved_record) && s.options.map(&.name) != options.map(&.name)
          return "cannot be changed after publishing"
        end
      end
    end
  end

  @[Persistent]
  property closed_at : Time?
  validates(closed_at) do
    if !new_record? && changed?(:closed_at)
      if (q = question?) && q.local? && !q.draft?
        if (s = @saved_record) && s.closed_at != closed_at
          return "cannot be changed after publishing"
        end
      end
    end
  end

  @[Persistent]
  property multiple_choice : Bool = false
  validates(multiple_choice) do
    if !new_record? && changed?(:multiple_choice)
      if (q = question?) && q.local? && !q.draft?
        if (s = @saved_record) && s.multiple_choice != multiple_choice
          return "cannot be changed after publishing"
        end
      end
    end
  end

  @[Persistent]
  property voters_count : Int32?

  def before_save
    # Convert relative `closed_at` to absolute time when associated
    # question is published.
    #
    # Draft polls store `closed_at` as a relative duration (seconds
    # from epoch) because users creating polls think in terms like
    # "expires in 3 days" rather than absolute deadlines.
    #
    # When the question transitions from draft to published, this hook
    # converts the relative duration to an absolute expiry time based
    # on the current time.
    #
    if (question = self.question?) && question.changed?(:published) && question.published && (closed_at = self.closed_at)
      self.closed_at = Time.utc + closed_at.to_unix.seconds
    end
  end

  def expired?
    return false if question?.try(&.draft?)
    (closed_at = self.closed_at) ? closed_at < Time.utc : false
  end

  # Adjusts vote tallies.
  #
  # Adds +1 to vote tallies for each vote created after the last
  # question update.
  #
  def adjust_votes(question, actor)
    votes = question.votes_by(actor)
    recent_votes = votes.select { |vote| vote.created_at > question.updated_at }
    if !recent_votes.empty?
      adjusted_options = options.map do |option|
        adjustment = recent_votes.count { |v| v.name == option.name }
        Option.new(option.name, option.votes_count + adjustment)
      end
      unique_voters_count = recent_votes.group_by(&.attributed_to.id).size
      adjusted_voters_count = (voters_count || 0) + unique_voters_count
      {options: adjusted_options, voters_count: adjusted_voters_count}
    else
      {options: options, voters_count: voters_count}
    end
  end
end
