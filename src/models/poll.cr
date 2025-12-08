require "../framework/model"
require "./activity_pub/object"

class Poll
  include Ktistec::Model
  include Ktistec::Model::Common

  @@table_name = "polls"

  @[Persistent]
  property question_iri : String?
  belongs_to question, class_name: ActivityPub::Object, foreign_key: question_iri, primary_key: iri
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
end
