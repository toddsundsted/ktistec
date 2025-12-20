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
    return "can't be empty" if options.empty?
    return "must contain at least 2 options" unless options.size > 1
  end

  @[Persistent]
  property closed_at : Time?

  @[Persistent]
  property voters_count : Int32?

  @[Persistent]
  property multiple_choice : Bool = false

  def expired?
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
    if recent_votes.any?
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

  def after_save
    if (closed_at = self.closed_at)
      if closed_at > Time.utc
        unless Task::NotifyPollExpiry.find?(question: self.question)
          Task::NotifyPollExpiry.new(source_iri: "", question: self.question).schedule(closed_at)
        end
      end
    end
  end
end
